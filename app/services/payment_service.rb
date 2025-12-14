# frozen_string_literal: true

class PaymentService
  class PaymentError < StandardError; end

  # Process a payment (real or simulated based on test_mode)
  # @param amount_cents [Integer] - Amount to charge in cents
  # @param payment_method [Hash] - Payment method details (card token, etc.)
  # @param order [Order] - The order being paid for
  # @param customer_email [String] - Customer's email
  # @param test_mode [Boolean] - Whether to simulate payment (default: false)
  # @return [Hash] - { success: boolean, charge_id: string, error: string }
  def self.process_payment(amount_cents:, payment_method:, order:, customer_email:, test_mode: false)
    if test_mode
      process_test_payment(amount_cents, payment_method, order, customer_email)
    else
      process_real_payment(amount_cents, payment_method, order, customer_email)
    end
  rescue Stripe::CardError => e
    Rails.logger.error "Stripe Card Error: #{e.message}"
    { success: false, error: e.message }
  rescue Stripe::StripeError => e
    Rails.logger.error "Stripe API Error: #{e.message}"
    { success: false, error: "Payment processing failed. Please try again." }
  rescue StandardError => e
    Rails.logger.error "Payment Error: #{e.class} - #{e.message}"
    { success: false, error: "An unexpected error occurred. Please try again." }
  end

  # Create a payment intent (for Stripe Checkout)
  # @param amount_cents [Integer] - Amount to charge in cents
  # @param customer_email [String] - Customer's email
  # @param order_id [Integer] - Order ID for reference
  # @param test_mode [Boolean] - Whether to simulate payment intent (default: false)
  # @return [Hash] - { success: boolean, client_secret: string, error: string }
  def self.create_payment_intent(amount_cents:, customer_email:, order_id:, test_mode: false)
    if test_mode
      create_test_payment_intent(amount_cents, customer_email, order_id)
    else
      create_real_payment_intent(amount_cents, customer_email, order_id)
    end
  rescue Stripe::StripeError => e
    Rails.logger.error "Stripe Payment Intent Error: #{e.message}"
    { success: false, error: "Failed to initialize payment. Please try again." }
  rescue StandardError => e
    Rails.logger.error "Payment Intent Error: #{e.class} - #{e.message}"
    { success: false, error: "An unexpected error occurred. Please try again." }
  end

  private

  # Real Stripe payment processing
  def self.process_real_payment(amount_cents, payment_method, order, customer_email)
    Rails.logger.info "💳 Processing real Stripe payment: $#{'%.2f' % (amount_cents / 100.0)}"

    charge = Stripe::Charge.create(
      amount: amount_cents,
      currency: 'usd',
      source: payment_method[:token],
      description: "Order ##{order.id} - Hafaloha",
      receipt_email: customer_email,
      metadata: {
        order_id: order.id,
        order_type: order.order_type
      }
    )

    {
      success: true,
      charge_id: charge.id,
      payment_method: 'stripe',
      card_last4: charge.source&.last4,
      card_brand: charge.source&.brand
    }
  end

  # Simulated payment for test mode
  def self.process_test_payment(amount_cents, payment_method, order, customer_email)
    Rails.logger.info "⚙️  TEST MODE: Simulating payment of $#{'%.2f' % (amount_cents / 100.0)}"
    Rails.logger.info "   Order ID: #{order.id}"
    Rails.logger.info "   Customer: #{customer_email}"
    Rails.logger.info "   Payment Method: #{payment_method.inspect}"

    # Simulate a slight delay (like a real API call)
    sleep(0.5)

    # Generate fake charge ID
    charge_id = "test_charge_#{SecureRandom.hex(12)}"

    {
      success: true,
      charge_id: charge_id,
      payment_method: 'test',
      card_last4: '4242',
      card_brand: 'Visa (Test)'
    }
  end

  # Real Stripe Payment Intent
  def self.create_real_payment_intent(amount_cents, customer_email, order_id)
    Rails.logger.info "💳 Creating real Stripe Payment Intent: $#{'%.2f' % (amount_cents / 100.0)}"

    intent = Stripe::PaymentIntent.create(
      amount: amount_cents,
      currency: 'usd',
      receipt_email: customer_email,
      metadata: {
        order_id: order_id
      }
    )

    {
      success: true,
      client_secret: intent.client_secret,
      payment_intent_id: intent.id
    }
  end

  # Test mode Payment Intent (simulated)
  def self.create_test_payment_intent(amount_cents, customer_email, order_id)
    Rails.logger.info "⚙️  TEST MODE: Creating simulated Payment Intent"
    Rails.logger.info "   Amount: $#{'%.2f' % (amount_cents / 100.0)}"
    Rails.logger.info "   Customer: #{customer_email}"
    Rails.logger.info "   Order ID: #{order_id}"

    # Generate fake client secret
    client_secret = "test_secret_#{SecureRandom.hex(16)}"

    {
      success: true,
      client_secret: client_secret,
      payment_intent_id: "test_pi_#{SecureRandom.hex(12)}"
    }
  end
end

