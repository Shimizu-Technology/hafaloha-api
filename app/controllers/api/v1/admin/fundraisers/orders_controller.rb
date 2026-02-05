module Api
  module V1
    module Admin
      module Fundraisers
        class OrdersController < BaseController
          before_action :set_fundraiser
          before_action :set_order, only: [ :show, :update ]

          # GET /api/v1/admin/fundraisers/:fundraiser_id/orders
          def index
            @orders = @fundraiser.fundraiser_orders.includes(:participant, :fundraiser_order_items)

            # Filter by status
            if params[:status].present?
              @orders = @orders.where(status: params[:status])
            end

            # Filter by payment status
            if params[:payment_status].present?
              @orders = @orders.where(payment_status: params[:payment_status])
            end

            # Filter by participant
            if params[:participant_id].present?
              @orders = @orders.where(participant_id: params[:participant_id])
            end

            # Search by order number, customer name, or email
            if params[:search].present?
              search = "%#{params[:search]}%"
              @orders = @orders.where(
                "order_number ILIKE ? OR customer_name ILIKE ? OR customer_email ILIKE ?",
                search, search, search
              )
            end

            # Date range filter
            if params[:from].present?
              @orders = @orders.where("created_at >= ?", params[:from].to_date.beginning_of_day)
            end
            if params[:to].present?
              @orders = @orders.where("created_at <= ?", params[:to].to_date.end_of_day)
            end

            # Order
            @orders = @orders.order(created_at: :desc)

            # Pagination
            page = params[:page]&.to_i || 1
            per_page = [ params[:per_page]&.to_i || 20, 100 ].min
            total = @orders.count
            @orders = @orders.limit(per_page).offset((page - 1) * per_page)

            # Stats for the filtered orders (before pagination)
            stats = {
              total_orders: @fundraiser.fundraiser_orders.count,
              total_revenue_cents: @fundraiser.fundraiser_orders.where(payment_status: "paid").sum(:total_cents),
              pending_orders: @fundraiser.fundraiser_orders.where(status: "pending").count,
              paid_orders: @fundraiser.fundraiser_orders.where(payment_status: "paid").count
            }

            render json: {
              orders: @orders.map { |o| serialize_order(o) },
              stats: stats,
              meta: {
                page: page,
                per_page: per_page,
                total: total
              }
            }
          end

          # GET /api/v1/admin/fundraisers/:fundraiser_id/orders/:id
          def show
            render json: { order: serialize_order_full(@order) }
          end

          # PUT /api/v1/admin/fundraisers/:fundraiser_id/orders/:id
          def update
            # Only allow updating certain fields
            allowed_params = order_params

            # Validate status transition
            if allowed_params[:status].present? && allowed_params[:status] != @order.status
              unless valid_status_transition?(@order.status, allowed_params[:status])
                render json: { error: "Invalid status transition from #{@order.status} to #{allowed_params[:status]}" }, status: :unprocessable_entity
                return
              end
            end

            if @order.update(allowed_params)
              render json: { order: serialize_order_full(@order) }
            else
              render json: { errors: @order.errors.full_messages }, status: :unprocessable_entity
            end
          end

          private

          def set_fundraiser
            @fundraiser = Fundraiser.find_by(id: params[:fundraiser_id]) ||
                          Fundraiser.find_by(slug: params[:fundraiser_id])
            render json: { error: "Fundraiser not found" }, status: :not_found unless @fundraiser
          end

          def set_order
            @order = @fundraiser.fundraiser_orders.find_by(id: params[:id])
            render json: { error: "Order not found" }, status: :not_found unless @order
          end

          def order_params
            params.require(:order).permit(
              :status, :payment_status, :admin_notes,
              :shipping_address_line1, :shipping_address_line2,
              :shipping_city, :shipping_state, :shipping_zip, :shipping_country
            )
          end

          def valid_status_transition?(from, to)
            valid_transitions = {
              "pending" => %w[paid processing cancelled],
              "paid" => %w[processing shipped cancelled],
              "processing" => %w[shipped cancelled],
              "shipped" => %w[delivered],
              "delivered" => [],
              "cancelled" => []
            }
            valid_transitions[from]&.include?(to)
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
              participant_id: order.participant_id,
              participant_name: order.participant&.name,
              participant_code: order.participant&.unique_code,
              subtotal_cents: order.subtotal_cents,
              shipping_cents: order.shipping_cents,
              tax_cents: order.tax_cents,
              total_cents: order.total_cents,
              item_count: order.fundraiser_order_items.sum(:quantity),
              created_at: order.created_at
            }
          end

          def serialize_order_full(order)
            serialize_order(order).merge(
              stripe_payment_intent_id: order.stripe_payment_intent_id,
              notes: order.notes,
              admin_notes: order.admin_notes,
              shipping_address: order.shipping_address,
              full_shipping_address: order.full_shipping_address,
              next_status_options: order.next_status_options,
              can_cancel: order.can_cancel?,
              items: order.fundraiser_order_items.includes(:fundraiser_product_variant).map { |i| serialize_order_item(i) },
              updated_at: order.updated_at
            )
          end

          def serialize_order_item(item)
            {
              id: item.id,
              product_name: item.product_name,
              variant_name: item.variant_name,
              sku: item.sku,
              quantity: item.quantity,
              price_cents: item.price_cents,
              total_price_cents: item.total_price_cents,
              variant_id: item.fundraiser_product_variant_id
            }
          end
        end
      end
    end
  end
end
