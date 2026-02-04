# Development Guide — Hafaloha V2 API

> **Project:** Hafaloha V2 API (Shopify replacement — long-term product)
> **Stack:** Ruby 3.3.4 · Rails 8.1.1 · PostgreSQL · Clerk auth · Stripe
> **Plane Board:** HAF (Hafaloha Orders)

---

## Quick Start

```bash
git clone git@github.com:Shimizu-Technology/hafaloha-api.git
cd hafaloha-api
bundle install
rails db:create db:migrate db:seed
cp .env.example .env   # Add Clerk + Stripe keys
rails s -p 3000
```

> Requires `.env` with Clerk and Stripe API keys configured.

---

## Gate Script

**Every PR must pass the gate before submission.**

```bash
./scripts/gate.sh
```

This runs:
1. **RSpec tests** — 30 tests
2. **RuboCop lint** — style/correctness checks
3. **Brakeman security scan** — static analysis for vulnerabilities

❌ If the gate fails, fix the issues before creating a PR. No exceptions.

### Pre-Existing Issues (Known Debt)

These exist in the codebase and are **not** blockers for new PRs:
- **1,989 RuboCop offenses** — legacy code, being cleaned up incrementally
- **1 Brakeman warning** — tracked, not critical
- **3 dependency vulnerabilities** — monitored

The gate script accounts for these. New code must not introduce *additional* issues.

---

## Development Commands

| Task | Command |
|------|---------|
| Install deps | `bundle install` |
| Start server | `rails s -p 3000` |
| Run tests | `bundle exec rspec` |
| Run linter | `bundle exec rubocop` |
| Security scan | `bundle exec brakeman` |
| Run gate | `./scripts/gate.sh` |
| Rails console | `rails c` |
| DB setup | `rails db:create db:migrate db:seed` |

---

## Environment Variables

Required in `.env`:
```
CLERK_SECRET_KEY=sk_...
CLERK_PUBLISHABLE_KEY=pk_...
STRIPE_SECRET_KEY=sk_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

---

## Closed-Loop Development Workflow

We use a "close the loop" approach where agents verify their own work before human review:

### Three Gates

1. **Sub-Agent Gate (automated)** — `./scripts/gate.sh` must pass (RSpec + RuboCop + Brakeman)
2. **Jerry Visual QA (real browser)** — Navigate pages, take screenshots, verify flows work
3. **Leon Final Review (human)** — Review PR + screenshots, approve/reject

Leon shifts from "test everything" to "approve verified work." The gate script is the first line of defense — no PR without a green gate.

### Branch Strategy

- All feature work branches from `staging`
- All PRs target `staging` (never `main` directly)
- `main` only gets updated when Leon approves merging staging
- Feature branches: `feature/<TICKET-ID>-description`

```bash
git checkout staging && git pull
git checkout -b feature/HAF-42-add-inventory-endpoint
```

### PR Process

- **Title:** `HAF-42: Add inventory management endpoint`
- **Body includes:** what changed, gate results, screenshots
- After creating PR:
  1. Move Plane ticket (HAF board) to **QA / Testing**
  2. Add PR link to the ticket

### Ticket Tracking

All work is tracked on the **HAF** board in [Plane](https://plane.shimizu-technology.com).

---

## Architecture Notes

- **Auth:** Clerk (JWT verification via `clerk-sdk-ruby`)
- **Payments:** Stripe integration for orders
- **This is the long-term product** — replaces Shopify for Hafaloha's ordering needs
- Paired with [hafaloha-web](../hafaloha-web/DEVELOPMENT.md)
