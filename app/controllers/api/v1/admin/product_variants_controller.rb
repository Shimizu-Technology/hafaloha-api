module Api
  module V1
    module Admin
      class ProductVariantsController < BaseController
        before_action :set_product
        before_action :set_variant, only: [:show, :update, :destroy]
        
        # GET /api/v1/admin/products/:product_id/variants
        def index
          render_success(
            @product.product_variants.map { |v| serialize_variant(v) }
          )
        end
        
        # GET /api/v1/admin/products/:product_id/variants/:id
        def show
          render_success(serialize_variant(@variant))
        end
        
        # POST /api/v1/admin/products/:product_id/variants
        def create
          @variant = @product.product_variants.new(variant_params)
          
          if @variant.save
            render_created(serialize_variant(@variant))
          else
            render_error('Failed to create variant', errors: @variant.errors.full_messages)
          end
        end
        
        # PATCH/PUT /api/v1/admin/products/:product_id/variants/:id
        def update
          if @variant.update(variant_params)
            render_success(serialize_variant(@variant), message: 'Variant updated successfully')
          else
            render_error('Failed to update variant', errors: @variant.errors.full_messages)
          end
        end
        
        # DELETE /api/v1/admin/products/:product_id/variants/:id
        def destroy
          if @variant.destroy
            render_success(nil, message: 'Variant deleted successfully')
          else
            render_error('Failed to delete variant', errors: @variant.errors.full_messages)
          end
        end
        
        # POST /api/v1/admin/products/:product_id/variants/:id/adjust_stock
        def adjust_stock
          @variant = @product.product_variants.find(params[:id])
          adjustment = params[:adjustment].to_i
          
          if adjustment > 0
            @variant.increment_stock!(adjustment)
            message = "Added #{adjustment} units to stock"
          elsif adjustment < 0
            @variant.decrement_stock!(adjustment.abs)
            message = "Removed #{adjustment.abs} units from stock"
          else
            return render_error('Adjustment must be non-zero')
          end
          
          render_success(serialize_variant(@variant), message: message)
        rescue => e
          render_error('Failed to adjust stock', errors: [e.message])
        end
        
        # POST /api/v1/admin/products/:product_id/variants/generate
        def generate
          sizes = params[:sizes] || []
          colors = params[:colors] || []
          
          if sizes.empty? && colors.empty?
            return render_error('At least one size or color must be provided')
          end
          
          # If only sizes provided, treat as size-only variants
          # If only colors provided, treat as color-only variants
          # If both provided, create all combinations
          
          variants_created = 0
          variants_skipped = 0
          errors = []
          
          if sizes.any? && colors.any?
            # Create size x color combinations
            sizes.each do |size|
              colors.each do |color|
                result = create_variant_if_not_exists(size, color)
                if result[:created]
                  variants_created += 1
                else
                  variants_skipped += 1
                end
                errors << result[:error] if result[:error]
              end
            end
          elsif sizes.any?
            # Size-only variants
            sizes.each do |size|
              result = create_variant_if_not_exists(size, nil)
              if result[:created]
                variants_created += 1
              else
                variants_skipped += 1
              end
              errors << result[:error] if result[:error]
            end
          else
            # Color-only variants
            colors.each do |color|
              result = create_variant_if_not_exists(nil, color)
              if result[:created]
                variants_created += 1
              else
                variants_skipped += 1
              end
              errors << result[:error] if result[:error]
            end
          end
          
          message = "Generated #{variants_created} new variant#{'s' unless variants_created == 1}"
          message += " (#{variants_skipped} skipped - already exist)" if variants_skipped > 0
          
          render_success(
            {
              variants: @product.product_variants.reload.map { |v| serialize_variant(v) },
              created: variants_created,
              skipped: variants_skipped,
              errors: errors
            },
            message: message
          )
        rescue => e
          render_error('Failed to generate variants', errors: [e.message])
        end
        
        private
        
        def set_product
          @product = Product.find_by(id: params[:product_id]) || Product.find_by(slug: params[:product_id])
          render_not_found('Product not found') unless @product
        end
        
        def set_variant
          @variant = @product.product_variants.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render_not_found('Variant not found')
        end
        
        def create_variant_if_not_exists(size, color)
          # Check if this combination already exists
          existing = @product.product_variants.find_by(size: size, color: color)
          return { created: false, variant: existing } if existing
          
          # Generate SKU
          sku_parts = [@product.sku_prefix]
          sku_parts << size.to_s.upcase.gsub(/\s+/, '-') if size.present?
          sku_parts << color.to_s.upcase.gsub(/\s+/, '-') if color.present?
          sku = sku_parts.join('-')
          
          # Generate variant name
          name_parts = []
          name_parts << size if size.present?
          name_parts << color if color.present?
          variant_name = name_parts.join(' / ')
          
          # Generate variant key (for frontend, lowercase with dashes)
          key_parts = []
          key_parts << size.to_s.downcase.gsub(/\s+/, '-') if size.present?
          key_parts << color.to_s.downcase.gsub(/\s+/, '-') if color.present?
          variant_key = key_parts.join('-')
          
          # Create variant with base price and 0 stock
          variant = @product.product_variants.create(
            size: size,
            color: color,
            sku: sku,
            variant_name: variant_name,
            variant_key: variant_key,
            price_cents: @product.base_price_cents,
            stock_quantity: 0,
            available: true,
            weight_oz: @product.weight_oz
          )
          
          if variant.persisted?
            { created: true, variant: variant }
          else
            { created: false, error: "Failed to create #{variant_name}: #{variant.errors.full_messages.join(', ')}" }
          end
        end
        
        def variant_params
          params.require(:product_variant).permit(
            :size,
            :color,
            :material,
            :variant_key,
            :variant_name,
            :sku,
            :price_cents,
            :stock_quantity,
            :low_stock_threshold,
            :available,
            :weight_oz,
            :shopify_variant_id,
            :barcode
          )
        end
        
        def serialize_variant(variant)
          {
            id: variant.id,
            product_id: variant.product_id,
            size: variant.size,
            color: variant.color,
            material: variant.material,
            variant_key: variant.variant_key,
            variant_name: variant.variant_name,
            display_name: variant.display_name,
            sku: variant.sku,
            price_cents: variant.price_cents,
            stock_quantity: variant.stock_quantity,
            low_stock_threshold: variant.low_stock_threshold,
            stock_status: variant.stock_status,
            low_stock: variant.low_stock?,
            available: variant.available,
            actually_available: variant.actually_available?,
            in_stock: variant.in_stock?,
            weight_oz: variant.weight_oz,
            shopify_variant_id: variant.shopify_variant_id,
            barcode: variant.barcode,
            created_at: variant.created_at,
            updated_at: variant.updated_at
          }
        end
      end
    end
  end
end

