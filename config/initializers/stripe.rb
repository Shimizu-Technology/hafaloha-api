# frozen_string_literal: true

# Stripe API configuration
# https://stripe.com/docs/api

# Check if we're running in test mode or production mode
APP_MODE = ENV.fetch("APP_MODE", "test").downcase

if APP_MODE == "test"
  # Test mode - bypass Stripe entirely
  Rails.logger.info "⚙️  Running in TEST mode - Stripe calls will be simulated"
  STRIPE_ENABLED = false
  STRIPE_PUBLISHABLE_KEY = "pk_test_simulated" # Placeholder for frontend
else
  # Production mode - use real Stripe
  if ENV["STRIPE_SECRET_KEY"].present?
    Stripe.api_key = ENV["STRIPE_SECRET_KEY"]
    STRIPE_ENABLED = true
    STRIPE_PUBLISHABLE_KEY = ENV["STRIPE_PUBLISHABLE_KEY"]
    Rails.logger.info "💳 Running in PRODUCTION mode - Using Stripe API"
    Rails.logger.info "   Publishable Key: #{STRIPE_PUBLISHABLE_KEY&.slice(0, 12)}..."
  else
    Rails.logger.warn "⚠️  STRIPE_SECRET_KEY not set - payments will fail in production mode"
    STRIPE_ENABLED = false
    STRIPE_PUBLISHABLE_KEY = nil
  end
end

# Make constants available globally
Rails.application.config.stripe_enabled = STRIPE_ENABLED
Rails.application.config.stripe_publishable_key = STRIPE_PUBLISHABLE_KEY
Rails.application.config.app_mode = APP_MODE
