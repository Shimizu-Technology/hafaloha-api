# frozen_string_literal: true

module Api
  module V1
    class OrdersController < ApplicationController
      include Authenticatable
      skip_before_action :authenticate_request, only: [:create, :show] # Allow guest checkout and order viewing
      before_action :authenticate_optional, only: [:create, :show]
      before_action :require_admin!, only: [:index, :update]

      # GET /api/v1/orders
      # List all orders (admin only)
      def index
        # Pagination
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 25).to_i
        
        # Base query
        orders_query = Order.includes(:order_items, :user).order(created_at: :desc)
        
        # Filters
        if params[:status].present?
          orders_query = orders_query.where(status: params[:status])
        end
        
        if params[:payment_status].present?
          orders_query = orders_query.where(payment_status: params[:payment_status])
        end
        
        if params[:order_type].present?
          orders_query = orders_query.where(order_type: params[:order_type])
        end
        
        # Search by order number, email, or name
        if params[:search].present?
          search_term = "%#{params[:search]}%"
          orders_query = orders_query.where(
            "order_number LIKE ? OR customer_email LIKE ? OR customer_name LIKE ?",
            search_term, search_term, search_term
          )
        end
        
        # Date range filter
        if params[:start_date].present?
          orders_query = orders_query.where("created_at >= ?", params[:start_date])
        end
        
        if params[:end_date].present?
          orders_query = orders_query.where("created_at <= ?", params[:end_date])
        end
        
        # Paginate
        total_count = orders_query.count
        orders = orders_query.offset((page - 1) * per_page).limit(per_page)
        
        render json: {
          orders: orders.map { |order| order_json(order) },
          pagination: {
            current_page: page,
            per_page: per_page,
            total_count: total_count,
            total_pages: (total_count.to_f / per_page).ceil
          }
        }
      end

      # POST /api/v1/orders
      # Create a new order from cart + shipping + payment
      def create
        # Get site settings to check test mode
        settings = SiteSetting.instance
        
        # Get cart items
        cart_items = get_cart_items
        
        if cart_items.empty?
          return render json: { error: 'Cart is empty' }, status: :unprocessable_entity
        end

        # Validate cart items are still available
        validation_errors = validate_cart_items(cart_items)
        if validation_errors.any?
          return render json: { error: 'Cart validation failed', issues: validation_errors }, status: :unprocessable_entity
        end

        # Create order
        order = build_order(cart_items)

        # Process payment
        payment_result = PaymentService.process_payment(
          amount_cents: order.total_cents,
          payment_method: order_params[:payment_method],
          order: order,
          customer_email: order.email,
          test_mode: settings.payment_test_mode
        )

        unless payment_result[:success]
          return render json: { error: payment_result[:error] }, status: :unprocessable_entity
        end

        # Save order with payment info
        # Valid payment statuses: pending, paid, failed, refunded
        order.payment_status = 'paid'  # Both test and real payments are 'paid'
        order.payment_intent_id = payment_result[:charge_id]
        
        Rails.logger.info "💾 Attempting to save order..."
        Rails.logger.info "   Order attributes: #{order.attributes.slice('order_type', 'status', 'email', 'phone', 'customer_name', 'shipping_city', 'shipping_state', 'payment_status').inspect}"
        
        if order.save
          Rails.logger.info "✅ Order saved successfully! Order ##{order.order_number}"
          # Deduct inventory (with locking to prevent race conditions)
          deduct_inventory(cart_items)
          
          # Clear cart
          clear_cart(cart_items)
          
          # Send confirmation emails (asynchronously via Sidekiq)
          # Only send customer emails if enabled in settings
          if settings.send_customer_emails
            SendOrderConfirmationEmailJob.perform_later(order.id)
          else
            Rails.logger.info "📧 Customer email disabled - skipping confirmation email for Order ##{order.order_number}"
          end
          
          # Always send admin notifications
          SendAdminNotificationEmailJob.perform_later(order.id)
          
          render json: {
            success: true,
            order: order_json(order),
            message: settings.payment_test_mode? ? 'Test order created successfully!' : 'Order placed successfully!'
          }, status: :created
        else
          Rails.logger.error "❌ Order validation failed:"
          order.errors.full_messages.each { |msg| Rails.logger.error "   - #{msg}" }
          render json: { error: 'Failed to create order', errors: order.errors.full_messages }, status: :unprocessable_entity
        end
      rescue StandardError => e
        Rails.logger.error "Order creation error: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        render json: { error: 'Failed to create order. Please try again.' }, status: :internal_server_error
      end

      # GET /api/v1/orders/:id
      # Get order details
      def show
        order = Order.includes(order_items: { product_variant: :product }).find(params[:id])
        
        render json: {
          order: detailed_order_json(order)
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Order not found' }, status: :not_found
      end

      # PATCH /api/v1/orders/:id
      # Update order (admin only - for status changes, notes, etc.)
      def update
        order = Order.find(params[:id])
        
        if order.update(order_update_params)
          render json: {
            success: true,
            order: detailed_order_json(order),
            message: 'Order updated successfully'
          }
        else
          render json: {
            success: false,
            errors: order.errors.full_messages
          }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Order not found' }, status: :not_found
      end

      private

      def get_cart_items
        if current_user
          current_user.cart_items.includes(product_variant: { product: :product_images })
        else
          session_id = request.headers['X-Session-ID'] || cookies[:session_id]
          return [] if session_id.blank?
          CartItem.where(session_id: session_id).includes(product_variant: { product: :product_images })
        end
      end

      def validate_cart_items(cart_items)
        issues = []
        
        cart_items.each do |item|
          variant = item.product_variant
          product = variant.product

          # Check if product is actually available (respects published + inventory)
          unless product.actually_available?
            issues << { 
              item_id: item.id, 
              product_name: product.name,
              variant_name: variant.display_name,
              message: "#{product.name} is no longer available" 
            }
            next
          end
          
          # Check variant availability (respects available flag + stock)
          unless variant.actually_available?
            issues << { 
              item_id: item.id, 
              product_name: product.name,
              variant_name: variant.display_name,
              message: "#{product.name} - #{variant.display_name} is out of stock" 
            }
            next
          end

          # Check sufficient stock based on inventory level
          case product.inventory_level
          when 'variant'
            if item.quantity > variant.stock_quantity
              issues << { 
                item_id: item.id, 
                product_name: product.name,
                variant_name: variant.display_name,
                message: "Only #{variant.stock_quantity} of #{product.name} - #{variant.display_name} available" 
              }
            end
            
          when 'product'
            product_stock = product.product_stock_quantity || 0
            if item.quantity > product_stock
              issues << { 
                item_id: item.id, 
                product_name: product.name,
                variant_name: variant.display_name,
                message: "Only #{product_stock} of #{product.name} available" 
              }
            end
            
          when 'none'
            # No stock validation needed
            next
          end
        end

        issues
      end

      def build_order(cart_items)
        shipping_address = order_params[:shipping_address]
        shipping_method_params = order_params[:shipping_method]
        
        order = Order.new(
          user: current_user,
          order_type: 'retail',
          status: 'pending',
          email: order_params[:email],
          phone: order_params[:phone],
          name: shipping_address[:name], # Customer name (saved to customer_name via alias)
          
          # Shipping address
          shipping_address_line1: shipping_address[:street1],
          shipping_address_line2: shipping_address[:street2],
          shipping_city: shipping_address[:city],
          shipping_state: shipping_address[:state],
          shipping_zip: shipping_address[:zip],
          shipping_country: shipping_address[:country] || 'US',
          
          # Shipping method (store as JSON/text with carrier and service info)
          shipping_method: "#{shipping_method_params[:carrier]} #{shipping_method_params[:service]}",
          shipping_cost_cents: shipping_method_params[:rate_cents]
        )

        # Calculate totals
        subtotal_cents = 0
        
        cart_items.each do |cart_item|
          item_price = cart_item.product_variant.price_cents
          item_total = item_price * cart_item.quantity
          
          order.order_items.build(
            product_variant: cart_item.product_variant,
            product_id: cart_item.product.id,
            quantity: cart_item.quantity,
            unit_price_cents: item_price,
            total_price_cents: item_total,
            product_name: cart_item.product.name,
            product_sku: cart_item.product_variant.sku,
            variant_name: cart_item.product_variant.display_name
          )
          
          subtotal_cents += item_total
        end

        order.subtotal_cents = subtotal_cents
        order.tax_cents = 0 # TODO: Calculate tax if needed
        order.total_cents = order.subtotal_cents + order.shipping_cost_cents + order.tax_cents
        
        order
      end

      def deduct_inventory(cart_items)
        cart_items.each do |item|
          variant = item.product_variant
          product = variant.product
          
          case product.inventory_level
          when 'variant'
            # Decrement variant-level stock
            variant.with_lock do
              new_stock = variant.stock_quantity - item.quantity
              if new_stock < 0
                raise StandardError, "Not enough stock for #{variant.sku}"
              end
              variant.update!(stock_quantity: new_stock)
            end
            
          when 'product'
            # Decrement product-level stock
            product.with_lock do
              new_stock = (product.product_stock_quantity || 0) - item.quantity
              if new_stock < 0
                raise StandardError, "Not enough stock for #{product.name}"
              end
              product.update!(product_stock_quantity: new_stock)
            end
            
          when 'none'
            # Do nothing - not tracking inventory
            next
          end
        end
      end

      def clear_cart(cart_items)
        cart_items.destroy_all
      end

      def order_json(order)
        {
          id: order.id,
          order_number: order.order_number,
          status: order.status,
          payment_status: order.payment_status,
          order_type: order.order_type,
          customer_name: order.name,
          customer_email: order.email,
          customer_phone: order.phone,
          subtotal_cents: order.subtotal_cents,
          shipping_cost_cents: order.shipping_cost_cents,
          tax_cents: order.tax_cents,
          total_cents: order.total_cents,
          shipping_method: order.shipping_method,
          shipping_address_line1: order.shipping_address_line1,
          shipping_address_line2: order.shipping_address_line2,
          shipping_city: order.shipping_city,
          shipping_state: order.shipping_state,
          shipping_zip: order.shipping_zip,
          shipping_country: order.shipping_country,
          created_at: order.created_at.iso8601,
          item_count: order.order_items.count,
          order_items: order.order_items.map do |item|
            {
              id: item.id,
              product_name: item.product_name,
              variant_name: item.variant_name,
              product_sku: item.product_sku,
              quantity: item.quantity,
              unit_price_cents: item.unit_price_cents,
              total_price_cents: item.total_price_cents
            }
          end
        }
      end

      def detailed_order_json(order)
        {
          id: order.id,
          order_number: order.order_number,
          status: order.status,
          payment_status: order.payment_status,
          order_type: order.order_type,
          customer_name: order.name,
          customer_email: order.email,
          customer_phone: order.phone,
          subtotal_cents: order.subtotal_cents,
          shipping_cost_cents: order.shipping_cost_cents,
          tax_cents: order.tax_cents,
          total_cents: order.total_cents,
          total_formatted: "$#{'%.2f' % (order.total_cents / 100.0)}",
          created_at: order.created_at.iso8601,
          shipping_method: order.shipping_method,
          shipping_address_line1: order.shipping_address_line1,
          shipping_address_line2: order.shipping_address_line2,
          shipping_city: order.shipping_city,
          shipping_state: order.shipping_state,
          shipping_zip: order.shipping_zip,
          shipping_country: order.shipping_country,
          order_items: order.order_items.map do |item|
            {
              id: item.id,
              product_name: item.product_name,
              variant_name: item.variant_name,
              product_sku: item.product_sku,
              quantity: item.quantity,
              unit_price_cents: item.unit_price_cents,
              total_price_cents: item.total_price_cents
            }
          end
        }
      end

      def order_params
        params.require(:order).permit(
          :email,
          :phone,
          shipping_address: [:name, :street1, :street2, :city, :state, :zip, :country],
          shipping_method: [:carrier, :service, :rate_cents, :rate_id],
          payment_method: [:token, :type]
        )
      end

      def order_update_params
        params.require(:order).permit(:status, :admin_notes, :tracking_number)
      end
    end
  end
end

