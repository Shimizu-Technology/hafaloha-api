# frozen_string_literal: true

# Clerk SDK configuration
require "clerk"

Clerk.configure do |config|
  config.api_key = ENV.fetch("CLERK_SECRET_KEY")
  config.logger = Rails.logger
end
