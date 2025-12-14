class SendOrderConfirmationEmailJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find(order_id)
    result = EmailService.send_order_confirmation(order)
    
    if result[:success]
      Rails.logger.info "✅ Order confirmation email sent for Order ##{order.id}"
    else
      Rails.logger.error "❌ Failed to send confirmation email for Order ##{order.id}: #{result[:error]}"
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "❌ Order ##{order_id} not found - cannot send confirmation email"
  rescue StandardError => e
    Rails.logger.error "❌ Error sending confirmation email: #{e.class} - #{e.message}"
    raise # Re-raise to allow job retry
  end
end

