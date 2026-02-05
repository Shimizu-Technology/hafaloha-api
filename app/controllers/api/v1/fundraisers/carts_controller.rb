module Api
  module V1
    module Fundraisers
      class CartsController < ApplicationController
        before_action :set_fundraiser
        before_action :load_cart

        # GET /api/v1/fundraisers/:fundraiser_slug/cart
        def show
          render json: { cart: serialize_cart }
        end

        # PUT /api/v1/fundraisers/:fundraiser_slug/cart
        # Add or update items in cart
        def update
          items = params[:items] || []
          errors = []

          items.each do |item_data|
            variant = FundraiserProductVariant.joins(:fundraiser_product)
                                              .where(fundraiser_products: { fundraiser_id: @fundraiser.id, published: true })
                                              .find_by(id: item_data[:variant_id])

            unless variant
              errors << { variant_id: item_data[:variant_id], error: "Variant not found" }
              next
            end

            quantity = item_data[:quantity].to_i

            if quantity <= 0
              # Remove item if quantity is 0 or less
              @cart[:items].delete(variant.id.to_s)
            else
              # Check stock
              if variant.fundraiser_product.inventory_level == "variant" && quantity > variant.stock_quantity
                errors << { variant_id: variant.id, error: "Only #{variant.stock_quantity} available" }
                next
              end

              @cart[:items][variant.id.to_s] = {
                variant_id: variant.id,
                quantity: quantity,
                price_cents: variant.price_cents,
                product_id: variant.fundraiser_product_id,
                product_name: variant.fundraiser_product.name,
                variant_name: variant.display_name
              }
            end
          end

          save_cart

          if errors.any?
            render json: { cart: serialize_cart, errors: errors }, status: :unprocessable_entity
          else
            render json: { cart: serialize_cart }
          end
        end

        # DELETE /api/v1/fundraisers/:fundraiser_slug/cart
        def destroy
          @cart = { items: {}, participant_code: nil }
          save_cart
          render json: { cart: serialize_cart, message: "Cart cleared" }
        end

        private

        def set_fundraiser
          @fundraiser = Fundraiser.published.find_by(slug: params[:fundraiser_slug])

          unless @fundraiser&.active?
            render json: { error: "Fundraiser not available" }, status: :not_found
          end
        end

        def load_cart
          cart_key = "fundraiser_cart_#{@fundraiser.id}"
          @cart = session[cart_key] || { items: {}, participant_code: nil }
          @cart = @cart.with_indifferent_access
          @cart[:items] ||= {}
        end

        def save_cart
          cart_key = "fundraiser_cart_#{@fundraiser.id}"
          session[cart_key] = @cart
        end

        def serialize_cart
          items = @cart[:items].map do |variant_id, item_data|
            variant = FundraiserProductVariant.includes(:fundraiser_product).find_by(id: variant_id)
            next nil unless variant

            product = variant.fundraiser_product

            {
              variant_id: variant.id,
              product_id: product.id,
              product_name: product.name,
              variant_name: variant.display_name,
              sku: variant.sku,
              quantity: item_data[:quantity],
              unit_price_cents: variant.price_cents,
              total_price_cents: variant.price_cents * item_data[:quantity],
              in_stock: variant.in_stock?,
              actually_available: variant.actually_available?,
              image_url: product.primary_image&.url
            }
          end.compact

          subtotal = items.sum { |i| i[:total_price_cents] }
          item_count = items.sum { |i| i[:quantity] }

          {
            fundraiser_id: @fundraiser.id,
            fundraiser_slug: @fundraiser.slug,
            items: items,
            item_count: item_count,
            subtotal_cents: subtotal,
            participant_code: @cart[:participant_code]
          }
        end
      end
    end
  end
end
