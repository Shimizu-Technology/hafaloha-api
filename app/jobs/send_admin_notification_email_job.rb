class SendAdminNotificationEmailJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find(order_id)
    result = EmailService.send_admin_notification(order)

    if result[:success]
      Rails.logger.info "✅ Admin notification email sent for Order ##{order.order_number}"
    else
      # In development, email failures are expected (domain not verified) - don't clutter logs
      if Rails.env.development?
        Rails.logger.info "ℹ️  Admin email not sent (expected in development): #{result[:error]}"
      else
        Rails.logger.error "❌ Failed to send admin notification for Order ##{order.order_number}: #{result[:error]}"
      end
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "❌ Order ##{order_id} not found - cannot send admin notification"
  rescue StandardError => e
    Rails.logger.error "❌ Error sending admin notification: #{e.class} - #{e.message}"
    raise # Re-raise to allow job retry
  end
end
