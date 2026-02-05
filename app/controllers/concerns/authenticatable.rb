# frozen_string_literal: true

module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_request
    attr_reader :current_user
  end

  private

  def authenticate_request
    token = extract_token
    return render_unauthorized unless token

    begin
      # Decode the JWT token to get the user ID
      decoded_token = JWT.decode(token, nil, false)
      payload = decoded_token.first

      clerk_id = payload["sub"]

      unless clerk_id
        Rails.logger.error("Missing clerk_id (sub) in JWT payload")
        return render_unauthorized("Invalid token payload")
      end

      Rails.logger.info("Fetching user info from Clerk for ID: #{clerk_id}")

      # Fetch user info from Clerk API
      clerk_client = Clerk::SDK.new
      clerk_user = clerk_client.users.find(clerk_id)

      # Extract primary email
      primary_email_obj = clerk_user["email_addresses"].find { |e| e["id"] == clerk_user["primary_email_address_id"] }
      email = primary_email_obj ? primary_email_obj["email_address"] : nil

      Rails.logger.info("Clerk user fetched - Email: #{email}")

      unless email
        Rails.logger.error("No email found for Clerk user #{clerk_id}")
        return render_unauthorized("User has no email address")
      end

      @current_user = find_or_create_user(clerk_id, email)
      Rails.logger.info("User authenticated: #{@current_user.email} (Admin: #{@current_user.admin?})")
    rescue JWT::DecodeError => e
      Rails.logger.error("JWT decode error: #{e.message}")
      render_unauthorized("Invalid token format")
    rescue StandardError => e
      Rails.logger.error("Authentication error: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))
      render_unauthorized("Authentication failed")
    end
  end

  def extract_token
    auth_header = request.headers["Authorization"]
    return unless auth_header&.start_with?("Bearer ")

    auth_header.split(" ").last
  end

  ADMIN_EMAILS = %w[
    shimizutechnology@gmail.com
    jerry.shimizutechnology@gmail.com
  ].freeze

  def find_or_create_user(clerk_id, email)
    user = User.find_or_create_by!(clerk_id: clerk_id) do |u|
      u.email = email
      u.role = ADMIN_EMAILS.include?(email) ? "admin" : "customer"
    end

    # Always sync admin status on login (handles users created before admin list was updated)
    expected_role = ADMIN_EMAILS.include?(email) ? "admin" : user.role
    user.update!(role: expected_role, email: email) if user.role != expected_role || user.email != email

    user
  end

  def render_unauthorized(message = "Unauthorized")
    render json: { error: message }, status: :unauthorized
  end

  # Helper to check if user is admin
  def require_admin!
    render json: { error: "Forbidden" }, status: :forbidden unless current_user&.admin?
  end

  # Helper to make authentication optional
  def authenticate_optional
    token = extract_token
    return unless token

    begin
      decoded_token = JWT.decode(token, nil, false)
      payload = decoded_token.first
      clerk_id = payload["sub"]

      return unless clerk_id

      clerk_client = Clerk::SDK.new
      clerk_user = clerk_client.users.find(clerk_id)

      primary_email_obj = clerk_user["email_addresses"].find { |e| e["id"] == clerk_user["primary_email_address_id"] }
      email = primary_email_obj ? primary_email_obj["email_address"] : nil

      @current_user = find_or_create_user(clerk_id, email) if email
    rescue
      # Silent fail for optional auth
      nil
    end
  end
end
