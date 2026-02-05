class SendOrderShippedEmailJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find(order_id)

    # Check if emails are enabled for this order type
    settings = SiteSetting.instance
    return unless settings.send_emails_for?(order.order_type)

    # Send order shipped email with tracking info
    EmailService.send_order_shipped_email(order)

    Rails.logger.info "✅ Sent shipped notification email for order #{order.order_number}"
  rescue StandardError => e
    Rails.logger.error "❌ Failed to send shipped email for order #{order_id}: #{e.message}"
    # Don't raise - we don't want email failures to break order updates
  end
end
