# frozen_string_literal: true

module Api
  module V1
    module Admin
      module Acai
        class OrdersController < Admin::BaseController
          # GET /api/v1/admin/acai/orders
          def index
            orders = Order.acai.includes(:order_items).recent

            # Filter by pickup date
            if params[:pickup_date].present?
              orders = orders.where(acai_pickup_date: params[:pickup_date])
            end

            # Filter by date range
            if params[:start_date].present? && params[:end_date].present?
              orders = orders.where(acai_pickup_date: params[:start_date]..params[:end_date])
            end

            # Filter by status
            if params[:status].present?
              orders = orders.where(status: params[:status])
            end

            # Pagination
            page = (params[:page] || 1).to_i
            per_page = (params[:per_page] || 20).to_i.clamp(1, 100)
            total = orders.count
            orders = orders.offset((page - 1) * per_page).limit(per_page)

            render json: {
              success: true,
              orders: orders.map { |o| order_json(o) },
              meta: {
                page: page,
                per_page: per_page,
                total: total,
                total_pages: (total.to_f / per_page).ceil
              }
            }
          end

          private

          def order_json(order)
            settings = AcaiSetting.instance
            {
              id: order.id,
              order_number: order.order_number,
              customer_name: order.customer_name,
              customer_email: order.customer_email,
              customer_phone: order.customer_phone,
              status: order.status,
              payment_status: order.payment_status,
              total_cents: order.total_cents,
              formatted_total: "$#{'%.2f' % (order.total_cents / 100.0)}",
              pickup_date: order.acai_pickup_date&.to_s,
              pickup_time: order.acai_pickup_time,
              crust_type: order.acai_crust_type,
              include_placard: order.acai_include_placard,
              placard_text: order.acai_placard_text,
              pickup_location: settings.pickup_location,
              notes: order.notes,
              created_at: order.created_at,
              items: order.order_items.map { |item|
                {
                  id: item.id,
                  product_name: item.product_name,
                  variant_name: item.variant_name,
                  quantity: item.quantity,
                  unit_price_cents: item.unit_price_cents,
                  total_price_cents: item.total_price_cents
                }
              }
            }
          end
        end
      end
    end
  end
end
