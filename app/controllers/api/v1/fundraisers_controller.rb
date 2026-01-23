module Api
  module V1
    class FundraisersController < ApplicationController
      before_action :set_fundraiser, only: [:show, :create_order]

      # GET /api/v1/fundraisers
      # Public list of active/published fundraisers
      def index
        @fundraisers = Fundraiser.published
                                 .includes(:participants, :fundraiser_products)
                                 .order(start_date: :desc)

        render json: {
          fundraisers: @fundraisers.map { |f| serialize_fundraiser_public(f) }
        }
      end

      # GET /api/v1/fundraisers/:slug
      # Public fundraiser detail page
      def show
        unless @fundraiser.status.in?(%w[active ended])
          render json: { error: 'Fundraiser not available' }, status: :not_found
          return
        end

        render json: {
          fundraiser: serialize_fundraiser_detail(@fundraiser),
          products: @fundraiser.fundraiser_products.active.by_position.map { |fp| serialize_product(fp) },
          participants: @fundraiser.participants.active.by_name.map { |p| serialize_participant(p) }
        }
      end

      # POST /api/v1/fundraisers/:slug/orders
      # Create a wholesale order for this fundraiser
      def create_order
        unless @fundraiser.active?
          return render json: { error: 'This fundraiser is no longer accepting orders' }, status: :unprocessable_entity
        end

        # Validate participant
        participant = nil
        if order_params[:participant_id].present?
          participant = @fundraiser.participants.active.find_by(id: order_params[:participant_id])
          unless participant
            return render json: { error: 'Invalid participant selected' }, status: :unprocessable_entity
          end
        end

        # Validate cart items
        cart_items = order_params[:items] || []
        if cart_items.empty?
          return render json: { error: 'Cart is empty' }, status: :unprocessable_entity
        end

        # Build order
        order = Order.new(
          order_type: 'wholesale',
          status: 'pending',
          fundraiser: @fundraiser,
          participant: participant,
          customer_name: order_params[:customer_name],
          customer_email: order_params[:customer_email],
          customer_phone: order_params[:customer_phone],
          notes: order_params[:notes]
        )

        # Handle shipping if allowed and requested
        if @fundraiser.allow_shipping && order_params[:shipping_address].present?
          shipping = order_params[:shipping_address]
          order.assign_attributes(
            shipping_address_line1: shipping[:street1],
            shipping_address_line2: shipping[:street2],
            shipping_city: shipping[:city],
            shipping_state: shipping[:state],
            shipping_zip: shipping[:zip],
            shipping_country: shipping[:country] || 'US',
            shipping_method: order_params.dig(:shipping_method, :service),
            shipping_cost_cents: order_params.dig(:shipping_method, :rate_cents) || 0
          )
        else
          order.shipping_cost_cents = 0
        end

        # Process items and calculate totals
        subtotal_cents = 0
        validation_errors = []

        cart_items.each do |item_params|
          fundraiser_product = @fundraiser.fundraiser_products.active.find_by(id: item_params[:fundraiser_product_id])
          
          unless fundraiser_product
            validation_errors << "Product not found or unavailable"
            next
          end

          variant = fundraiser_product.product.product_variants.find_by(id: item_params[:variant_id])
          unless variant
            validation_errors << "Variant not found for #{fundraiser_product.name}"
            next
          end

          quantity = item_params[:quantity].to_i
          
          # Validate quantity constraints
          if fundraiser_product.min_quantity && quantity < fundraiser_product.min_quantity
            validation_errors << "Minimum quantity for #{fundraiser_product.name} is #{fundraiser_product.min_quantity}"
            next
          end
          
          if fundraiser_product.max_quantity && quantity > fundraiser_product.max_quantity
            validation_errors << "Maximum quantity for #{fundraiser_product.name} is #{fundraiser_product.max_quantity}"
            next
          end

          # Check stock
          if variant.product.inventory_level == 'variant' && quantity > variant.stock_quantity
            validation_errors << "Only #{variant.stock_quantity} of #{fundraiser_product.name} (#{variant.display_name}) available"
            next
          end

          item_total = fundraiser_product.price_cents * quantity
          
          order.order_items.build(
            product_variant: variant,
            product_id: fundraiser_product.product_id,
            quantity: quantity,
            unit_price_cents: fundraiser_product.price_cents,
            total_price_cents: item_total,
            product_name: fundraiser_product.name,
            product_sku: variant.sku,
            variant_name: variant.display_name
          )
          
          subtotal_cents += item_total
        end

        if validation_errors.any?
          return render json: { error: 'Cart validation failed', issues: validation_errors }, status: :unprocessable_entity
        end

        order.subtotal_cents = subtotal_cents
        order.tax_cents = 0
        order.total_cents = subtotal_cents + (order.shipping_cost_cents || 0)

        # Process payment
        settings = SiteSetting.instance
        payment_result = PaymentService.process_payment(
          amount_cents: order.total_cents,
          payment_method: order_params[:payment_method],
          order: order,
          customer_email: order.customer_email,
          test_mode: settings.payment_test_mode
        )

        unless payment_result[:success]
          return render json: { error: payment_result[:error] }, status: :unprocessable_entity
        end

        order.payment_status = 'paid'
        order.payment_intent_id = payment_result[:charge_id]

        if order.save
          # Deduct inventory
          deduct_inventory(order.order_items)
          
          # Update fundraiser raised amount
          @fundraiser.update_raised_amount!
          
          # Send emails
          if settings.send_emails_for?('wholesale')
            SendOrderConfirmationEmailJob.perform_later(order.id)
          end
          SendAdminNotificationEmailJob.perform_later(order.id)
          
          render json: {
            success: true,
            order: serialize_order(order),
            thank_you_message: @fundraiser.thank_you_message
          }, status: :created
        else
          render json: { error: 'Failed to create order', errors: order.errors.full_messages }, status: :unprocessable_entity
        end
      rescue StandardError => e
        Rails.logger.error "Fundraiser order error: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        render json: { error: 'Failed to create order. Please try again.' }, status: :internal_server_error
      end

      private

      def deduct_inventory(order_items)
        order_items.each do |item|
          variant = item.product_variant
          product = variant.product
          
          case product.inventory_level
          when 'variant'
            variant.with_lock do
              new_stock = variant.stock_quantity - item.quantity
              variant.update!(stock_quantity: [new_stock, 0].max)
            end
          when 'product'
            product.with_lock do
              new_stock = (product.product_stock_quantity || 0) - item.quantity
              product.update!(product_stock_quantity: [new_stock, 0].max)
            end
          end
        end
      end

      def order_params
        params.require(:order).permit(
          :participant_id,
          :customer_name,
          :customer_email,
          :customer_phone,
          :notes,
          shipping_address: [:street1, :street2, :city, :state, :zip, :country],
          shipping_method: [:service, :rate_cents],
          payment_method: [:token, :type],
          items: [:fundraiser_product_id, :variant_id, :quantity]
        )
      end

      def serialize_order(order)
        {
          id: order.id,
          order_number: order.order_number,
          status: order.status,
          payment_status: order.payment_status,
          customer_name: order.customer_name,
          customer_email: order.customer_email,
          subtotal_cents: order.subtotal_cents,
          shipping_cost_cents: order.shipping_cost_cents,
          total_cents: order.total_cents,
          created_at: order.created_at.iso8601,
          fundraiser_name: @fundraiser.name,
          participant_name: order.participant&.display_name,
          pickup_location: @fundraiser.pickup_location,
          pickup_instructions: @fundraiser.pickup_instructions
        }
      end

      private

      def set_fundraiser
        @fundraiser = Fundraiser.includes(
          :participants,
          fundraiser_products: { product: [:product_images, :product_variants] }
        ).find_by(slug: params[:id]) || Fundraiser.find_by(id: params[:id])

        render json: { error: 'Fundraiser not found' }, status: :not_found unless @fundraiser
      end

      def serialize_fundraiser_public(fundraiser)
        {
          id: fundraiser.id,
          name: fundraiser.name,
          slug: fundraiser.slug,
          description: fundraiser.description&.truncate(200),
          start_date: fundraiser.start_date,
          end_date: fundraiser.end_date,
          image_url: fundraiser.image_url,
          goal_amount_cents: fundraiser.goal_amount_cents,
          raised_amount_cents: fundraiser.raised_amount_cents,
          progress_percentage: fundraiser.progress_percentage,
          is_active: fundraiser.active?,
          is_ended: fundraiser.ended?,
          product_count: fundraiser.fundraiser_products.active.count,
          participant_count: fundraiser.participants.active.count
        }
      end

      def serialize_fundraiser_detail(fundraiser)
        {
          id: fundraiser.id,
          name: fundraiser.name,
          slug: fundraiser.slug,
          description: fundraiser.description,
          public_message: fundraiser.public_message,
          start_date: fundraiser.start_date,
          end_date: fundraiser.end_date,
          image_url: fundraiser.image_url,
          goal_amount_cents: fundraiser.goal_amount_cents,
          raised_amount_cents: fundraiser.raised_amount_cents,
          progress_percentage: fundraiser.progress_percentage,
          contact_name: fundraiser.contact_name,
          contact_email: fundraiser.contact_email,
          contact_phone: fundraiser.contact_phone,
          pickup_location: fundraiser.pickup_location,
          pickup_instructions: fundraiser.pickup_instructions,
          allow_shipping: fundraiser.allow_shipping,
          shipping_note: fundraiser.shipping_note,
          thank_you_message: fundraiser.thank_you_message,
          is_active: fundraiser.active?,
          is_ended: fundraiser.ended?,
          can_order: fundraiser.active? # Only active fundraisers accept orders
        }
      end

      def serialize_product(fundraiser_product)
        product = fundraiser_product.product
        {
          id: fundraiser_product.id,
          product_id: product.id,
          name: product.name,
          slug: product.slug,
          description: product.description,
          price_cents: fundraiser_product.price_cents,
          min_quantity: fundraiser_product.min_quantity,
          max_quantity: fundraiser_product.max_quantity,
          image_url: product.primary_image&.signed_url,
          images: product.product_images.map do |img|
            {
              id: img.id,
              url: img.signed_url,
              alt_text: img.alt_text,
              primary: img.primary
            }
          end,
          variants: product.product_variants.where(available: true).map do |v|
            {
              id: v.id,
              display_name: v.display_name,
              size: v.size,
              color: v.color,
              sku: v.sku,
              in_stock: v.in_stock?,
              stock_quantity: v.stock_quantity
            }
          end,
          in_stock: product.in_stock?
        }
      end

      def serialize_participant(participant)
        {
          id: participant.id,
          name: participant.name,
          participant_number: participant.participant_number,
          display_name: participant.display_name
        }
      end
    end
  end
end
