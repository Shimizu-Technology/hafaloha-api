class ApplicationController < ActionController::API
  # --- Production error handling (HAF-16) ---
  # In production, catch unhandled errors and return clean JSON
  # instead of leaking stack traces and file paths.
  unless Rails.env.development? || Rails.env.test?
    rescue_from StandardError do |e|
      Rails.logger.error "Unhandled #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace&.first(10)&.join("\n")
      render json: { error: "Internal server error" }, status: :internal_server_error
    end
  end

  rescue_from ActiveRecord::RecordNotFound do |e|
    render json: { error: "Record not found" }, status: :not_found
  end

  rescue_from ActionController::ParameterMissing do |e|
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
