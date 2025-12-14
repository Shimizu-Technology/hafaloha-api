# frozen_string_literal: true

# Resend Email API configuration
# https://resend.com/docs/send-with-ruby

if ENV['RESEND_API_KEY'].present?
  Resend.api_key = ENV['RESEND_API_KEY']
  Rails.logger.info "✅ Resend initialized with API key"
else
  Rails.logger.warn "⚠️  RESEND_API_KEY not set - email notifications will not work"
end

