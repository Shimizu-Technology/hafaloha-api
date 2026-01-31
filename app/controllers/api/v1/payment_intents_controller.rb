# frozen_string_literal: true

module Api
  module V1
    class PaymentIntentsController < ApplicationController
      include Authenticatable
      skip_before_action :authenticate_request, only: [:create]
      before_action :authenticate_optional, only: [:create]

      # POST /api/v1/payment_intents
      # Creates a Stripe PaymentIntent for the current cart
      def create
        settings = SiteSetting.instance

        # Get cart items to calculate amount
        cart_items = get_cart_items
        if cart_items.empty?
          return render json: { error: "Cart is empty" }, status: :unprocessable_entity
        end

        # Calculate total
        subtotal_cents = cart_items.sum { |item| item.product_variant.price_cents * item.quantity }
        shipping_cost_cents = (params[:shipping_cost_cents] || 0).to_i
        total_cents = subtotal_cents + shipping_cost_cents

        if total_cents <= 0
          return render json: { error: "Order total must be greater than zero" }, status: :unprocessable_entity
        end

        email = params[:email] || current_user&.email
        unless email.present?
          return render json: { error: "Email is required" }, status: :unprocessable_entity
        end

        # Create payment intent via PaymentService
        result = PaymentService.create_payment_intent(
          amount_cents: total_cents,
          customer_email: email,
          order_id: 0, # Will be set when order is created
          test_mode: settings.payment_test_mode
        )

        if result[:success]
          render json: {
            client_secret: result[:client_secret],
            payment_intent_id: result[:payment_intent_id],
            amount_cents: total_cents
          }, status: :ok
        else
          render json: { error: result[:error] }, status: :unprocessable_entity
        end
      rescue StandardError => e
        Rails.logger.error "PaymentIntent creation error: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        render json: { error: "Failed to create payment intent. Please try again." }, status: :internal_server_error
      end

      private

      def get_cart_items
        if current_user
          current_user.cart_items.includes(product_variant: :product)
        else
          session_id = request.headers["X-Session-ID"] || request.cookies["session_id"]
          return [] if session_id.blank?
          CartItem.where(session_id: session_id).includes(product_variant: :product)
        end
      end
    end
  end
end
