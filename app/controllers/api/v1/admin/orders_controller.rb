# frozen_string_literal: true

module Api
  module V1
    module Admin
    class OrdersController < ApplicationController
      include Authenticatable
        before_action :authenticate_request
        before_action :require_admin!
        before_action :set_order, only: [:show, :update, :notify, :refund]

      # GET /api/v1/admin/orders
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

      # GET /api/v1/admin/orders/:id
      # Get single order details
      def show
        render json: { order: detailed_order_json(@order) }
      end

      # PATCH/PUT /api/v1/admin/orders/:id
      # Update order (status, tracking, notes)
      def update
        old_status = @order.status
        
        if @order.update(order_update_params)
          # Handle status changes
          if @order.saved_change_to_status?
            case @order.status
            when 'shipped'
              # Send shipping notification with tracking
              SendOrderShippedEmailJob.perform_later(@order.id) if @order.tracking_number.present?
            when 'ready'
              # Send ready for pickup notification
              SendOrderReadyEmailJob.perform_later(@order.id)
            when 'cancelled'
              # Restore inventory when order is cancelled
              restore_inventory(@order, current_user)
            end
          end
          
          render json: { 
            order: detailed_order_json(@order),
            message: 'Order updated successfully'
          }
        else
          render json: { error: @order.errors.full_messages.join(', ') }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/admin/orders/:id/notify
      # Resend notification email to customer
      def notify
        case @order.status
        when 'shipped'
          if @order.tracking_number.present?
            SendOrderShippedEmailJob.perform_later(@order.id)
            render json: { message: 'Shipping notification sent to customer' }
          else
            render json: { error: 'Order has no tracking number' }, status: :unprocessable_entity
          end
        when 'ready'
          SendOrderReadyEmailJob.perform_later(@order.id)
          render json: { message: 'Ready for pickup notification sent to customer' }
        else
          render json: { error: "Cannot send notification for orders with status '#{@order.status}'" }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/admin/orders/:id/refund
      # Process a refund for an order
      def refund
        amount_cents = params[:amount_cents].to_i
        reason = params[:reason]

        # Validate amount
        if amount_cents <= 0
          return render json: { error: 'amount_cents must be greater than 0' }, status: :unprocessable_entity
        end

        # Validate the order can be refunded
        unless @order.can_refund?
          return render json: { error: 'This order cannot be refunded' }, status: :unprocessable_entity
        end

        # Validate amount doesn't exceed refundable amount
        if amount_cents > @order.refundable_amount_cents
          return render json: {
            error: "Refund amount exceeds refundable amount (max: #{@order.refundable_amount_cents} cents)"
          }, status: :unprocessable_entity
        end

        # Determine test mode
        test_mode = ENV['APP_MODE'] == 'test'

        # Process the refund
        refund = PaymentService.refund_payment(
          order: @order,
          amount_cents: amount_cents,
          reason: reason,
          admin_user: current_user,
          test_mode: test_mode
        )

        if refund.succeeded?
          # Update payment status if fully refunded
          if @order.reload.fully_refunded?
            @order.update!(payment_status: 'refunded')
          end

          # Restore inventory for full refunds
          if @order.fully_refunded?
            restore_inventory_for_refund(@order, current_user)
          end

          # Send refund notification email
          OrderMailer.refund_notification(@order, refund).deliver_later

          render json: {
            message: 'Refund processed successfully',
            refund: refund_json(refund),
            order: detailed_order_json(@order.reload)
          }
        else
          render json: {
            error: 'Refund failed',
            details: refund.metadata&.dig('error') || 'An error occurred processing the refund'
          }, status: :unprocessable_entity
        end
      rescue StandardError => e
        Rails.logger.error "Refund error for order ##{@order.order_number}: #{e.message}"
        render json: { error: "Refund failed: #{e.message}" }, status: :internal_server_error
      end


      private

      def set_order
        @order = Order.includes(:order_items, :user, :refunds).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Order not found' }, status: :not_found
      end

      def get_cart_items
        if current_user
          # First, merge any session cart items to the user
          merge_session_cart_to_user
          current_user.cart_items.includes(product_variant: { product: :product_images })
        else
          session_id = request.headers['X-Session-ID'] || cookies[:session_id]
          return [] if session_id.blank?
          CartItem.where(session_id: session_id).includes(product_variant: { product: :product_images })
        end
      end

      # Merge session-based cart items to the logged-in user
      def merge_session_cart_to_user
        session_id = request.headers['X-Session-ID'] || request.cookies['session_id']
        return unless current_user && session_id.present?
        
        session_items = CartItem.where(session_id: session_id)
        return if session_items.empty?
        
        session_items.each do |session_item|
          existing_item = current_user.cart_items.find_by(product_variant_id: session_item.product_variant_id)
          
          if existing_item
            existing_item.update(quantity: existing_item.quantity + session_item.quantity)
            session_item.destroy
          else
            session_item.update(user_id: current_user.id, session_id: nil)
          end
        end
      end

      def validate_cart_items(cart_items)
        issues = []
        
        cart_items.each do |item|
          variant = item.product_variant
          product = variant.product

          # Check if product is published and variant is available
          if !(product.published? && variant.available)
            issues << { item_id: item.id, message: "#{product.name} is no longer available" }
          elsif !variant.in_stock?
            issues << { item_id: item.id, message: "#{product.name} - #{variant.display_name} is out of stock" }
          elsif item.quantity > variant.stock_quantity
            issues << { item_id: item.id, message: "Only #{variant.stock_quantity} of #{product.name} available" }
          end
        end

        issues
      end

      def build_order(cart_items)
        shipping_address = order_params[:shipping_address] || {}
        shipping_method_params = order_params[:shipping_method] || {}
        
        order = Order.new(
          user: current_user,
          order_type: 'retail',
          status: 'pending',
          email: order_params[:email] || order_params[:customer_email],
          phone: order_params[:phone] || order_params[:customer_phone],
          name: shipping_address[:name] || order_params[:customer_name],
          
          # Shipping address
          shipping_address_line1: shipping_address[:street1] || order_params[:shipping_address_line1],
          shipping_address_line2: shipping_address[:street2] || order_params[:shipping_address_line2],
          shipping_city: shipping_address[:city] || order_params[:shipping_city],
          shipping_state: shipping_address[:state] || order_params[:shipping_state],
          shipping_zip: shipping_address[:zip] || order_params[:shipping_zip],
          shipping_country: shipping_address[:country] || order_params[:shipping_country] || 'US',
          
          # Shipping method (store as JSON/text with carrier and service info)
          shipping_method: [shipping_method_params[:carrier], shipping_method_params[:service]].compact.join(' ').presence,
          shipping_cost_cents: shipping_method_params[:rate_cents] || 0
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

      def deduct_inventory(cart_items, order)
        cart_items.each do |item|
          variant = item.product_variant
          product = variant.product
          
          case product.inventory_level
          when 'variant'
            # Use row locking to prevent race conditions
            variant.with_lock do
              previous_stock = variant.stock_quantity
              new_stock = previous_stock - item.quantity
              if new_stock < 0
                raise StandardError, "Not enough stock for #{variant.sku}"
              end
              variant.update!(stock_quantity: new_stock)
              
              # Create audit record inside the lock for atomicity
              InventoryAudit.record_order_placed(
                variant: variant,
                quantity: item.quantity,
                order: order,
                previous_qty: previous_stock
              )
            end
            
          when 'product'
            # Decrement product-level stock with audit trail
            product.with_lock do
              previous_stock = product.product_stock_quantity || 0
              new_stock = previous_stock - item.quantity
              if new_stock < 0
                raise StandardError, "Not enough stock for #{product.name}"
              end
              product.update!(product_stock_quantity: new_stock)
              
              # Create audit record for product-level tracking
              InventoryAudit.record_product_stock_change(
                product: product,
                previous_qty: previous_stock,
                new_qty: new_stock,
                reason: "Order ##{order.order_number} placed",
                audit_type: 'order_placed',
                order: order
              )
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

      # Restore inventory when an order is cancelled
      def restore_inventory(order, user = nil)
        order.order_items.includes(product_variant: :product).each do |item|
          variant = item.product_variant
          next unless variant # Skip if variant was deleted
          
          product = variant.product
          
          case product.inventory_level
          when 'variant'
            variant.with_lock do
              previous_stock = variant.stock_quantity
              new_stock = previous_stock + item.quantity
              variant.update!(stock_quantity: new_stock)
              
              # Create audit record for cancellation
              InventoryAudit.record_order_cancelled(
                variant: variant,
                quantity: item.quantity,
                order: order,
                user: user
              )
            end
            
          when 'product'
            product.with_lock do
              previous_stock = product.product_stock_quantity || 0
              new_stock = previous_stock + item.quantity
              product.update!(product_stock_quantity: new_stock)
              
              # Create audit record for product-level tracking
              InventoryAudit.record_product_stock_change(
                product: product,
                previous_qty: previous_stock,
                new_qty: new_stock,
                reason: "Order ##{order.order_number} cancelled - stock restored",
                audit_type: 'order_cancelled',
                order: order,
                user: user
              )
            end
          end
        end
        
        Rails.logger.info "📦 Inventory restored for cancelled order ##{order.order_number}"
      end

      def order_json(order)
        json = {
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
        
        # Add acai-specific fields for acai orders
        if order.order_type == 'acai'
          settings = AcaiSetting.instance
          json.merge!(
            acai_pickup_date: order.acai_pickup_date&.to_s,
            acai_pickup_time: order.acai_pickup_time, # Now stored as string
            acai_crust_type: order.acai_crust_type,
            acai_include_placard: order.acai_include_placard,
            acai_placard_text: order.acai_placard_text,
            pickup_location: settings.pickup_location,
            pickup_phone: settings.pickup_phone
          )
        end
        
        json
      end

      def detailed_order_json(order)
        json = {
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
          updated_at: order.updated_at.iso8601,
          shipping_method: order.shipping_method,
          shipping_address_line1: order.shipping_address_line1,
          shipping_address_line2: order.shipping_address_line2,
          shipping_city: order.shipping_city,
          shipping_state: order.shipping_state,
          shipping_zip: order.shipping_zip,
          shipping_country: order.shipping_country,
          tracking_number: order.tracking_number,
          admin_notes: order.admin_notes,
          notes: order.notes,
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
        
        # Add refund history
        json[:refunds] = order.refunds.recent.map { |r| refund_json(r) }

        # Add acai-specific fields for acai orders
        if order.order_type == 'acai'
          acai_settings = AcaiSetting.instance
          json.merge!(
            acai_pickup_date: order.acai_pickup_date&.to_s,
            acai_pickup_time: order.acai_pickup_time, # Now stored as string
            acai_crust_type: order.acai_crust_type,
            acai_include_placard: order.acai_include_placard,
            acai_placard_text: order.acai_placard_text,
            pickup_location: acai_settings.pickup_location,
            pickup_phone: acai_settings.pickup_phone
          )
        end
        
        json
      end

      def refund_json(refund)
        {
          id: refund.id,
          amount_cents: refund.amount_cents,
          amount_formatted: "$#{'%.2f' % (refund.amount_cents / 100.0)}",
          status: refund.status,
          reason: refund.reason,
          stripe_refund_id: refund.stripe_refund_id,
          created_at: refund.created_at.iso8601,
          admin_user: refund.user&.name || refund.user&.email
        }
      end

      # Restore inventory when a full refund is processed
      def restore_inventory_for_refund(order, user = nil)
        order.order_items.includes(product_variant: :product).each do |item|
          variant = item.product_variant
          next unless variant

          product = variant.product

          case product.inventory_level
          when 'variant'
            variant.with_lock do
              previous_stock = variant.stock_quantity
              new_stock = previous_stock + item.quantity
              variant.update!(stock_quantity: new_stock)

              InventoryAudit.record_order_refunded(
                variant: variant,
                quantity: item.quantity,
                order: order,
                user: user
              )
            end

          when 'product'
            product.with_lock do
              previous_stock = product.product_stock_quantity || 0
              new_stock = previous_stock + item.quantity
              product.update!(product_stock_quantity: new_stock)

              InventoryAudit.record_product_stock_change(
                product: product,
                previous_qty: previous_stock,
                new_qty: new_stock,
                reason: "Order #" + '#{order.order_number}' + " refunded - stock restored",
                audit_type: 'order_refunded',
                order: order,
                user: user
              )
            end
          end
        end

        Rails.logger.info "Inventory restored for refunded order #" + '#{order.order_number}'
      end

      def order_params
        params.require(:order).permit(
          :email, :phone,
          :customer_name, :customer_email, :customer_phone,
          :shipping_address_line1, :shipping_address_line2,
          :shipping_city, :shipping_state, :shipping_zip, :shipping_country,
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
end

