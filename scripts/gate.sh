#!/usr/bin/env bash
#
# Hafaloha API — Gate Script
# Runs all quality checks before code can be committed/pushed.
# Exit code 0 = all clear, non-zero = gate failed.
#
set -uo pipefail

cd "$(dirname "$0")/.."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
BOLD='\033[1m'

PASSED=0
FAILED=0
WARNINGS=0

pass()  { echo -e "  ${GREEN}✓${NC} $1"; ((PASSED++)); }
fail()  { echo -e "  ${RED}✗${NC} $1"; ((FAILED++)); }
warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; ((WARNINGS++)); }

echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  🚪 Hafaloha API — Gate Check${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
echo ""

# Load .env for test environment (dotenv-rails only loads in development)
if [ -f .env ]; then
  export $(grep -v '^\s*#' .env | grep -v '^\s*$' | xargs) 2>/dev/null
fi

# Unset DATABASE_URL so test env uses database.yml's test config
unset DATABASE_URL

export RAILS_ENV=test

# ─── 1. RSpec ────────────────────────────────────────────────────────────
echo -e "${BOLD}1. RSpec Tests${NC}"
if bundle exec rspec --format progress 2>&1; then
  pass "All tests passed"
else
  fail "Tests failed (see output above)"
fi
echo ""

# ─── 2. RuboCop ──────────────────────────────────────────────────────────
echo -e "${BOLD}2. RuboCop (Style & Linting)${NC}"
if bundle exec rubocop --format simple 2>&1; then
  pass "No offenses"
else
  EXIT_CODE=$?
  if [ $EXIT_CODE -eq 1 ]; then
    fail "RuboCop offenses found (see above)"
  else
    fail "RuboCop error (exit $EXIT_CODE)"
  fi
fi
echo ""

# ─── 3. Brakeman (Security) ─────────────────────────────────────────────
echo -e "${BOLD}3. Brakeman (Security Scanner)${NC}"
if bundle exec brakeman --quiet --no-pager 2>&1; then
  pass "No security warnings"
else
  warn "Brakeman found warnings (review above)"
fi
echo ""

# ─── 4. Bundle Audit ─────────────────────────────────────────────────────
echo -e "${BOLD}4. Bundle Audit (Gem Vulnerabilities)${NC}"
if bundle exec bundle-audit check --update 2>&1; then
  pass "No vulnerable gems"
else
  warn "Vulnerable gems found (see above)"
fi
echo ""

# ─── 5. Hardcoded Secrets ────────────────────────────────────────────────
echo -e "${BOLD}5. Hardcoded Secrets Check${NC}"
SECRET_PATTERNS='(sk_live_|sk_test_|pk_live_|AKIA[A-Z0-9]{16}|password\s*=\s*["\x27][^"\x27]+["\x27]|secret_key\s*=\s*["\x27])'
MATCHES=$(grep -rn --include="*.rb" --include="*.yml" --include="*.yaml" \
  -E "$SECRET_PATTERNS" \
  app/ config/ lib/ db/ 2>/dev/null \
  | grep -v '\.env' \
  | grep -v 'config/credentials' \
  | grep -v '#.*secret' \
  | grep -v 'ENV\[' \
  | grep -v 'ENV\.fetch' \
  | grep -v 'Rails\.application\.credentials' \
  | grep -v 'example' \
  | grep -v 'TODO' \
  || true)

if [ -z "$MATCHES" ]; then
  pass "No hardcoded secrets found"
else
  fail "Possible hardcoded secrets:"
  echo "$MATCHES" | while read -r line; do
    echo -e "    ${RED}→${NC} $line"
  done
fi
echo ""

# ─── 6. Debug Statements ─────────────────────────────────────────────────
echo -e "${BOLD}6. Debug Statements Check${NC}"
DEBUG_PATTERNS='(binding\.pry|binding\.irb|byebug|debugger|puts\s+["\x27]|pp\s+["\x27]|console\.log)'
DEBUG_MATCHES=$(grep -rn --include="*.rb" \
  -E "$DEBUG_PATTERNS" \
  app/ lib/ 2>/dev/null \
  | grep -v '#.*binding' \
  | grep -v 'spec/' \
  || true)

if [ -z "$DEBUG_MATCHES" ]; then
  pass "No debug statements found"
else
  fail "Debug statements found:"
  echo "$DEBUG_MATCHES" | while read -r line; do
    echo -e "    ${RED}→${NC} $line"
  done
fi
echo ""

# ─── Summary ─────────────────────────────────────────────────────────────
echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}Passed:${NC}   $PASSED"
echo -e "  ${RED}Failed:${NC}   $FAILED"
echo -e "  ${YELLOW}Warnings:${NC} $WARNINGS"
echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"

if [ $FAILED -gt 0 ]; then
  echo -e "  ${RED}${BOLD}🚫 GATE FAILED${NC}"
  exit 1
else
  echo -e "  ${GREEN}${BOLD}✅ GATE PASSED${NC}"
  exit 0
fi
