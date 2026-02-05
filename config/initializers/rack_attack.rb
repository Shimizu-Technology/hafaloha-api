# frozen_string_literal: true

# Rack::Attack configuration for rate limiting
class Rack::Attack
  # Throttle contact form submissions: 5 requests per minute per IP
  throttle("contact_form/ip", limit: 5, period: 60) do |req|
    req.ip if req.path == "/api/v1/contact" && req.post?
  end

  # Return a 429 Too Many Requests response with JSON body
  self.throttled_responder = lambda do |_env|
    [
      429,
      { "Content-Type" => "application/json" },
      [ { error: "Too many requests. Please try again later." }.to_json ]
    ]
  end
end
