module Api
  module V1
    module Admin
      module Fundraisers
        class ProductVariantsController < BaseController
          before_action :set_fundraiser
          before_action :set_product
          before_action :set_variant, only: [ :show, :update, :destroy, :adjust_stock ]

          # GET /api/v1/admin/fundraisers/:fundraiser_id/products/:product_id/variants
          def index
            @variants = @product.fundraiser_product_variants

            # Filter by availability
            @variants = @variants.available if params[:available] == "true"

            render json: {
              variants: @variants.map { |v| serialize_variant(v) }
            }
          end

          # GET /api/v1/admin/fundraisers/:fundraiser_id/products/:product_id/variants/:id
          def show
            render json: { variant: serialize_variant_full(@variant) }
          end

          # POST /api/v1/admin/fundraisers/:fundraiser_id/products/:product_id/variants
          def create
            @variant = @product.fundraiser_product_variants.new(variant_params)

            # Set default price from product if not provided
            @variant.price_cents ||= @product.base_price_cents

            if @variant.save
              render json: { variant: serialize_variant(@variant) }, status: :created
            else
              render json: { errors: @variant.errors.full_messages }, status: :unprocessable_entity
            end
          end

          # PUT /api/v1/admin/fundraisers/:fundraiser_id/products/:product_id/variants/:id
          def update
            if @variant.update(variant_params)
              render json: { variant: serialize_variant(@variant) }
            else
              render json: { errors: @variant.errors.full_messages }, status: :unprocessable_entity
            end
          end

          # DELETE /api/v1/admin/fundraisers/:fundraiser_id/products/:product_id/variants/:id
          def destroy
            if @variant.fundraiser_order_items.exists?
              render json: { error: "Cannot delete variant with existing orders" }, status: :unprocessable_entity
              return
            end

            @variant.destroy
            render json: { message: "Variant deleted successfully" }
          end

          # POST /api/v1/admin/fundraisers/:fundraiser_id/products/:product_id/variants/:id/adjust_stock
          def adjust_stock
            adjustment = params[:adjustment].to_i
            reason = params[:reason]

            if adjustment.zero?
              render json: { error: "Adjustment must be non-zero" }, status: :unprocessable_entity
              return
            end

            new_quantity = @variant.stock_quantity + adjustment

            if new_quantity < 0
              render json: { error: "Cannot reduce stock below zero" }, status: :unprocessable_entity
              return
            end

            @variant.update!(stock_quantity: new_quantity)

            render json: {
              variant: serialize_variant(@variant),
              adjustment: {
                previous_quantity: @variant.stock_quantity - adjustment,
                new_quantity: new_quantity,
                adjustment: adjustment,
                reason: reason
              }
            }
          end

          # POST /api/v1/admin/fundraisers/:fundraiser_id/products/:product_id/variants/generate
          # Generate variants from option combinations
          def generate
            options = params[:options] || {}
            # Example: { "size": ["S", "M", "L"], "color": ["Red", "Blue"] }

            if options.blank?
              render json: { error: "Options are required" }, status: :unprocessable_entity
              return
            end

            # Delete existing non-default variants if requested
            if params[:replace] == "true"
              @product.fundraiser_product_variants.where(is_default: false).destroy_all
            end

            # Generate combinations
            option_keys = options.keys
            option_values = options.values

            # Cartesian product of all option values
            combinations = option_values.first.product(*option_values[1..])

            created = []
            errors = []

            combinations.each do |combo|
              combo = [ combo ] unless combo.is_a?(Array)
              opts = option_keys.zip(combo).to_h

              variant = @product.fundraiser_product_variants.new(
                options: opts,
                price_cents: @product.base_price_cents,
                available: true,
                stock_quantity: params[:default_stock]&.to_i || 0,
                weight_oz: @product.weight_oz
              )

              # Set legacy columns for convenience
              variant.size = opts["size"] || opts["Size"]
              variant.color = opts["color"] || opts["Color"]
              variant.material = opts["material"] || opts["Material"]

              if variant.save
                created << serialize_variant(variant)
              else
                errors << { options: opts, errors: variant.errors.full_messages }
              end
            end

            # Delete the default variant if we created real variants
            @product.fundraiser_product_variants.where(is_default: true).destroy_all if created.any?

            render json: {
              created: created,
              errors: errors,
              summary: {
                total: combinations.length,
                created_count: created.length,
                error_count: errors.length
              }
            }
          end

          private

          def set_fundraiser
            @fundraiser = Fundraiser.find_by(id: params[:fundraiser_id]) ||
                          Fundraiser.find_by(slug: params[:fundraiser_id])
            render json: { error: "Fundraiser not found" }, status: :not_found unless @fundraiser
          end

          def set_product
            @product = @fundraiser.fundraiser_products.find_by(id: params[:product_id])
            render json: { error: "Product not found" }, status: :not_found unless @product
          end

          def set_variant
            @variant = @product.fundraiser_product_variants.find_by(id: params[:id])
            render json: { error: "Variant not found" }, status: :not_found unless @variant
          end

          def variant_params
            params.require(:variant).permit(
              :sku, :variant_name, :variant_key,
              :size, :color, :material,
              :price_cents, :compare_at_price_cents,
              :stock_quantity, :available, :is_default,
              :weight_oz, :low_stock_threshold,
              options: {}
            )
          end

          def serialize_variant(variant)
            {
              id: variant.id,
              fundraiser_product_id: variant.fundraiser_product_id,
              sku: variant.sku,
              variant_name: variant.variant_name,
              variant_key: variant.variant_key,
              display_name: variant.display_name,
              size: variant.size,
              color: variant.color,
              material: variant.material,
              options: variant.options,
              price_cents: variant.price_cents,
              compare_at_price_cents: variant.compare_at_price_cents,
              stock_quantity: variant.stock_quantity,
              available: variant.available,
              is_default: variant.is_default,
              weight_oz: variant.weight_oz,
              stock_status: variant.stock_status,
              in_stock: variant.in_stock?,
              actually_available: variant.actually_available?,
              created_at: variant.created_at
            }
          end

          def serialize_variant_full(variant)
            serialize_variant(variant).merge(
              product_name: variant.fundraiser_product&.name,
              low_stock_threshold: variant.low_stock_threshold,
              updated_at: variant.updated_at
            )
          end
        end
      end
    end
  end
end
