# frozen_string_literal: true

module Api
  module V1
    module Admin
      class DashboardController < ApplicationController
        include Authenticatable
        before_action :authenticate_request
        before_action :require_admin!

        # GET /api/v1/admin/dashboard/stats
        def stats
          total_orders = Order.count
          total_revenue_cents = Order.where(payment_status: 'paid').sum(:total_cents)
          pending_orders = Order.where(status: 'pending').count
          total_products = Product.where(published: true).count

          render json: {
            total_orders: total_orders,
            total_revenue_cents: total_revenue_cents,
            pending_orders: pending_orders,
            total_products: total_products
          }
        end
      end
    end
  end
end

