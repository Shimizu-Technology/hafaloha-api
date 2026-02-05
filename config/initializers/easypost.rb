# frozen_string_literal: true

# EasyPost API configuration
# https://www.easypost.com/docs/api

# EasyPost v7+ uses a client instance rather than a global API key
# We'll create a client when needed in the ShippingService

if ENV["EASYPOST_API_KEY"].present?
  Rails.logger.info "✅ EasyPost API key configured"

  # Fix macOS SSL/CRL issue by ensuring Ruby uses the correct certificate bundle
  # This prevents "certificate verify failed (unable to get certificate CRL)" errors
  unless ENV["SSL_CERT_FILE"]
    cert_file = "/opt/homebrew/etc/ca-certificates/cert.pem"
    if File.exist?(cert_file)
      ENV["SSL_CERT_FILE"] = cert_file
      Rails.logger.info "✅ SSL_CERT_FILE set to: #{cert_file}"
    else
      Rails.logger.warn "⚠️  CA certificates not found at #{cert_file}"
    end
  end
else
  Rails.logger.warn "⚠️  EASYPOST_API_KEY not set - shipping rate calculation will use fallback rates"
end
