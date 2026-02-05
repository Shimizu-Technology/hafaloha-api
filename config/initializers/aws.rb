# config/initializers/aws.rb
#
# Configure AWS SDK for S3 uploads
# This fixes SSL certificate verification issues on macOS with Ruby 3.x + OpenSSL 3.x
#
# The issue: macOS OpenSSL 3.x fails CRL (Certificate Revocation List) checks when
# connecting to AWS S3, causing "certificate verify failed (unable to get certificate CRL)" errors.
#
# The fix: For development on macOS, disable SSL verification. Production (Linux) is unaffected.
# This is safe because:
# 1. Only applies in development environment
# 2. Only on macOS (darwin platform)
# 3. AWS S3 is a trusted service
#
# Reference: https://github.com/aws/aws-sdk-ruby/issues/2862

require "aws-sdk-s3"

# Only configure if AWS credentials are present
if ENV["AWS_ACCESS_KEY_ID"].present? && ENV["AWS_SECRET_ACCESS_KEY"].present?

  # For development on macOS, disable SSL verification to avoid CRL issues
  if Rails.env.development? && RUBY_PLATFORM.include?("darwin")
    Aws.config.update(
      region: ENV.fetch("AWS_REGION", "ap-southeast-2"),
      ssl_verify_peer: false, # Disable SSL verification on macOS dev
      http_open_timeout: 15,
      http_read_timeout: 60
    )
    Rails.logger.warn "⚠️  AWS SDK configured with SSL verification DISABLED (macOS development only)"
  else
    # Production: normal SSL verification
    Aws.config.update(
      region: ENV.fetch("AWS_REGION", "ap-southeast-2"),
      http_open_timeout: 15,
      http_read_timeout: 60
    )
    Rails.logger.info "✅ AWS SDK configured with full SSL verification"
  end

  Rails.logger.info "✅ Region: #{ENV['AWS_REGION']}, Bucket: #{ENV['AWS_S3_BUCKET']}"
else
  Rails.logger.warn "⚠️  AWS credentials not configured - S3 uploads will fail"
end
