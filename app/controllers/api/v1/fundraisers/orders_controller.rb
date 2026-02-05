module Api
  module V1
    module Fundraisers
      class OrdersController < ApplicationController
        before_action :set_fundraiser, only: [ :create, :show ]
        before_action :set_order, only: [ :show ]

        # POST /api/v1/fundraisers/:fundraiser_slug/orders
        def create
          unless @fundraiser.active?
            return render json: { error: "This fundraiser is no longer accepting orders" }, status: :unprocessable_entity
          end

          # Validate participant (optional)
          participant = nil
          if order_params[:participant_code].present?
            participant = @fundraiser.participants.active.find_by(unique_code: order_params[:participant_code])
            unless participant
              return render json: { error: "Invalid participant code" }, status: :unprocessable_entity
            end
          elsif order_params[:participant_id].present?
            participant = @fundraiser.participants.active.find_by(id: order_params[:participant_id])
            unless participant
              return render json: { error: "Invalid participant" }, status: :unprocessable_entity
            end
          end

          # Validate cart items
          cart_items = order_params[:items] || []
          if cart_items.empty?
            return render json: { error: "Cart is empty" }, status: :unprocessable_entity
          end

          # Build order
          @order = FundraiserOrder.new(
            fundraiser: @fundraiser,
            participant: participant,
            status: "pending",
            payment_status: "pending",
            customer_name: order_params[:customer_name],
            customer_email: order_params[:customer_email],
            customer_phone: order_params[:customer_phone],
            notes: order_params[:notes]
          )

          # Handle shipping address if provided
          if order_params[:shipping_address].present?
            shipping = order_params[:shipping_address]
            @order.assign_attributes(
              shipping_address_line1: shipping[:line1] || shipping[:street1],
              shipping_address_line2: shipping[:line2] || shipping[:street2],
              shipping_city: shipping[:city],
              shipping_state: shipping[:state],
              shipping_zip: shipping[:zip],
              shipping_country: shipping[:country] || "US"
            )
            @order.shipping_cents = order_params[:shipping_cents].to_i
          end

          # Process items and calculate totals
          subtotal_cents = 0
          validation_errors = []

          cart_items.each do |item_params|
            variant = @fundraiser.fundraiser_products
                                 .published
                                 .joins(:fundraiser_product_variants)
                                 .find_by(fundraiser_product_variants: { id: item_params[:variant_id] })
                                 &.fundraiser_product_variants
                                 &.find_by(id: item_params[:variant_id])

            unless variant
              validation_errors << "Variant #{item_params[:variant_id]} not found"
              next
            end

            unless variant.available?
              validation_errors << "#{variant.display_name} is no longer available"
              next
            end

            product = variant.fundraiser_product
            quantity = item_params[:quantity].to_i

            if quantity <= 0
              validation_errors << "Invalid quantity for #{product.name}"
              next
            end

            # Check stock based on inventory level
            case product.inventory_level
            when "variant"
              if quantity > variant.stock_quantity
                validation_errors << "Only #{variant.stock_quantity} of #{product.name} (#{variant.display_name}) available"
                next
              end
            when "product"
              if quantity > (product.product_stock_quantity || 0)
                validation_errors << "Only #{product.product_stock_quantity} of #{product.name} available"
                next
              end
            end

            item_total = variant.price_cents * quantity

            @order.fundraiser_order_items.build(
              fundraiser_product_variant: variant,
              quantity: quantity,
              price_cents: variant.price_cents,
              product_name: product.name,
              variant_name: variant.display_name
            )

            subtotal_cents += item_total
          end

          if validation_errors.any?
            return render json: { error: "Cart validation failed", issues: validation_errors }, status: :unprocessable_entity
          end

          @order.subtotal_cents = subtotal_cents
          @order.tax_cents = order_params[:tax_cents].to_i
          @order.total_cents = subtotal_cents + (@order.shipping_cents || 0) + (@order.tax_cents || 0)

          # Process payment if payment method provided
          if order_params[:payment_method].present?
            payment_result = process_payment(@order, order_params[:payment_method])

            unless payment_result[:success]
              return render json: { error: payment_result[:error] }, status: :unprocessable_entity
            end

            @order.payment_status = "paid"
            @order.stripe_payment_intent_id = payment_result[:payment_intent_id]
            @order.status = "paid"
          end

          if @order.save
            # Deduct inventory
            deduct_inventory(@order)

            # Update fundraiser raised amount
            @fundraiser.update_raised_amount! if @order.payment_status == "paid"

            # Clear cart
            clear_cart

            # TODO: Send confirmation emails
            # SendFundraiserOrderConfirmationJob.perform_later(@order.id)

            render json: {
              success: true,
              order: serialize_order(@order),
              thank_you_message: @fundraiser.thank_you_message
            }, status: :created
          else
            render json: { error: "Failed to create order", errors: @order.errors.full_messages }, status: :unprocessable_entity
          end
        rescue StandardError => e
          Rails.logger.error "Fundraiser order error: #{e.class} - #{e.message}"
          Rails.logger.error e.backtrace.first(10).join("\n")
          render json: { error: "Failed to create order. Please try again." }, status: :internal_server_error
        end

        # GET /api/v1/fundraisers/:fundraiser_slug/orders/:id
        def show
          render json: { order: serialize_order(@order) }
        end

        private

        def set_fundraiser
          @fundraiser = Fundraiser.published.find_by(slug: params[:fundraiser_slug])
          render json: { error: "Fundraiser not found" }, status: :not_found unless @fundraiser
        end

        def set_order
          @order = @fundraiser.fundraiser_orders.find_by(id: params[:id]) ||
                   @fundraiser.fundraiser_orders.find_by(order_number: params[:id])
          render json: { error: "Order not found" }, status: :not_found unless @order
        end

        def order_params
          params.require(:order).permit(
            :participant_id, :participant_code,
            :customer_name, :customer_email, :customer_phone,
            :notes, :shipping_cents, :tax_cents,
            shipping_address: [ :line1, :line2, :street1, :street2, :city, :state, :zip, :country ],
            payment_method: [ :token, :type, :payment_method_id ],
            items: [ :variant_id, :quantity ]
          )
        end

        def process_payment(order, payment_method)
          # Use existing PaymentService if available
          if defined?(PaymentService)
            PaymentService.process_payment(
              amount_cents: order.total_cents,
              payment_method: payment_method,
              order: order,
              customer_email: order.customer_email
            )
          else
            # Fallback: Direct Stripe integration
            Stripe.api_key = ENV["STRIPE_SECRET_KEY"]

            intent = Stripe::PaymentIntent.create(
              amount: order.total_cents,
              currency: "usd",
              payment_method: payment_method[:payment_method_id] || payment_method[:token],
              confirm: true,
              receipt_email: order.customer_email,
              metadata: {
                fundraiser_id: order.fundraiser_id,
                fundraiser_name: order.fundraiser.name,
                order_type: "fundraiser"
              },
              automatic_payment_methods: {
                enabled: true,
                allow_redirects: "never"
              }
            )

            { success: true, payment_intent_id: intent.id }
          end
        rescue Stripe::StripeError => e
          { success: false, error: e.message }
        end

        def deduct_inventory(order)
          order.fundraiser_order_items.each do |item|
            variant = item.fundraiser_product_variant
            product = variant.fundraiser_product

            case product.inventory_level
            when "variant"
              variant.decrement_stock!(item.quantity)
            when "product"
              product.with_lock do
                new_qty = [ (product.product_stock_quantity || 0) - item.quantity, 0 ].max
                product.update!(product_stock_quantity: new_qty)
              end
            end
          end
        end

        def clear_cart
          cart_key = "fundraiser_cart_#{@fundraiser.id}"
          session.delete(cart_key)
        end

        def serialize_order(order)
          {
            id: order.id,
            order_number: order.order_number,
            status: order.status,
            payment_status: order.payment_status,
            customer_name: order.customer_name,
            customer_email: order.customer_email,
            customer_phone: order.customer_phone,
            participant_name: order.participant&.name,
            participant_code: order.participant&.unique_code,
            subtotal_cents: order.subtotal_cents,
            shipping_cents: order.shipping_cents,
            tax_cents: order.tax_cents,
            total_cents: order.total_cents,
            shipping_address: order.shipping_address,
            items: order.fundraiser_order_items.map do |item|
              {
                id: item.id,
                product_name: item.product_name,
                variant_name: item.variant_name,
                quantity: item.quantity,
                price_cents: item.price_cents,
                total_price_cents: item.total_price_cents
              }
            end,
            fundraiser: {
              name: order.fundraiser.name,
              pickup_location: order.fundraiser.pickup_location,
              pickup_instructions: order.fundraiser.pickup_instructions
            },
            created_at: order.created_at.iso8601
          }
        end
      end
    end
  end
end
