module Api
  module V1
    module Admin
      class ProductsController < BaseController
        before_action :set_product, only: [ :show, :update, :destroy ]

        # GET /api/v1/admin/products
        def index
          @products = Product.includes(:product_variants, :product_images, :collections)
                             .order(created_at: :desc)

          # Filters
          @products = @products.where(published: params[:published]) if params[:published].present?
          @products = @products.where(archived: params[:archived]) if params[:archived].present?
          @products = @products.active unless params[:show_archived] == "true" # Default: hide archived
          @products = @products.where(product_type: params[:product_type]) if params[:product_type].present?
          @products = @products.joins(:collections).where(collections: { id: params[:collection_id] }) if params[:collection_id].present?

          # Search
          if params[:search].present?
            @products = @products.where("name ILIKE ? OR description ILIKE ?", "%#{params[:search]}%", "%#{params[:search]}%")
          end

          render_success(
            @products.map { |p| serialize_product_summary(p) }
          )
        end

        # GET /api/v1/admin/products/:id
        def show
          render_success(serialize_product_full(@product))
        end

        # POST /api/v1/admin/products
        def create
          @product = Product.new(product_params)

          if @product.save
            # Add to collections if provided
            if params[:collection_ids].present?
              @product.collection_ids = params[:collection_ids]
            end

            render_created(serialize_product_full(@product))
          else
            render_error("Failed to create product", errors: @product.errors.full_messages)
          end
        end

        # PATCH/PUT /api/v1/admin/products/:id
        def update
          if @product.update(product_params)
            # Update collections if provided
            if params[:collection_ids].present?
              @product.collection_ids = params[:collection_ids]
            end

            render_success(serialize_product_full(@product), message: "Product updated successfully")
          else
            render_error("Failed to update product", errors: @product.errors.full_messages)
          end
        end

        # DELETE /api/v1/admin/products/:id (Actually archives instead of deleting)
        def destroy
          if @product.archive!
            render_success(nil, message: "Product archived successfully")
          else
            render_error("Failed to archive product", errors: @product.errors.full_messages)
          end
        end

        # POST /api/v1/admin/products/:id/archive
        def archive
          @product = Product.find_by(id: params[:id])
          return render_not_found("Product not found") unless @product

          if @product.archive!
            render_success(serialize_product_summary(@product), message: "Product archived successfully")
          else
            render_error("Failed to archive product", errors: @product.errors.full_messages)
          end
        end

        # POST /api/v1/admin/products/:id/unarchive
        def unarchive
          @product = Product.find_by(id: params[:id])
          return render_not_found("Product not found") unless @product

          if @product.unarchive!
            render_success(serialize_product_summary(@product), message: "Product unarchived successfully")
          else
            render_error("Failed to unarchive product", errors: @product.errors.full_messages)
          end
        end

        # POST /api/v1/admin/products/:id/duplicate
        def duplicate
          @product = Product.find_by(id: params[:id])
          return render_not_found("Product not found") unless @product

          new_product = @product.dup
          new_product.name = "#{@product.name} (Copy)"
          new_product.slug = nil # Will be auto-generated
          new_product.published = false

          if new_product.save
            # Duplicate variants
            @product.product_variants.each do |variant|
              new_variant = variant.dup
              new_variant.product = new_product
              new_variant.sku = nil # Will be auto-generated
              new_variant.save
            end

            # Duplicate images
            @product.product_images.each do |image|
              new_image = image.dup
              new_image.product = new_product
              new_image.save
            end

            # Copy collections
            new_product.collection_ids = @product.collection_ids

            render_created(serialize_product_full(new_product), message: "Product duplicated successfully")
          else
            render_error("Failed to duplicate product", errors: new_product.errors.full_messages)
          end
        end

        private

        def set_product
          @product = Product.includes(:product_variants, :product_images, :collections)
                            .find_by(id: params[:id]) ||
                     Product.includes(:product_variants, :product_images, :collections)
                            .find_by(slug: params[:id])
          render_not_found("Product not found") unless @product
        end

        def product_params
          params.require(:product).permit(
            :name,
            :slug,
            :description,
            :base_price_cents,
            :sale_price_cents,
            :new_product,
            :sku_prefix,
            :track_inventory,
            :inventory_level,
            :product_stock_quantity,
            :product_low_stock_threshold,
            :weight_oz,
            :published,
            :featured,
            :product_type,
            :vendor,
            :meta_title,
            :meta_description,
            :shopify_product_id,
            collection_ids: []
          )
        end

        def serialize_product_summary(product)
          # Calculate total variant stock if variant-level tracking
          total_variant_stock = if product.inventory_level == "variant"
            product.product_variants.sum(:stock_quantity)
          else
            nil
          end

          {
            id: product.id,
            name: product.name,
            slug: product.slug,
            base_price_cents: product.base_price_cents,
            sale_price_cents: product.sale_price_cents,
            new_product: product.new_product,
            sku_prefix: product.sku_prefix,
            published: product.published,
            featured: product.featured,
            archived: product.archived,
            product_type: product.product_type,
            track_inventory: product.track_inventory,
            inventory_level: product.inventory_level,
            product_stock_quantity: product.product_stock_quantity,
            product_low_stock_threshold: product.product_low_stock_threshold,
            product_stock_status: product.product_stock_status,
            product_low_stock: product.product_low_stock?,
            total_variant_stock: total_variant_stock,
            primary_image_url: product.primary_image&.signed_url,
            variant_count: product.product_variants.count,
            in_stock: product.in_stock?,
            actually_available: product.actually_available?,
            collections: product.collections.map { |c| { id: c.id, name: c.name, slug: c.slug } },
            created_at: product.created_at,
            updated_at: product.updated_at
          }
        end

        def serialize_product_full(product)
          serialize_product_summary(product).merge(
            description: product.description,
            weight_oz: product.weight_oz,
            vendor: product.vendor,
            meta_title: product.meta_title,
            meta_description: product.meta_description,
            shopify_product_id: product.shopify_product_id,
            collection_ids: product.collections.pluck(:id),
            variants: product.product_variants.map { |v| serialize_variant(v) },
            images: product.product_images.by_position.map { |i| serialize_image(i) }
          )
        end

        def serialize_variant(variant)
          {
            id: variant.id,
            options: variant.options,
            size: variant.size,
            color: variant.color,
            variant_key: variant.variant_key,
            variant_name: variant.variant_name,
            sku: variant.sku,
            price_cents: variant.price_cents,
            stock_quantity: variant.stock_quantity,
            low_stock_threshold: variant.low_stock_threshold,
            available: variant.available,
            actually_available: variant.actually_available?,
            weight_oz: variant.weight_oz,
            shopify_variant_id: variant.shopify_variant_id,
            barcode: variant.barcode
          }
        end

        def serialize_image(image)
          {
            id: image.id,
            url: image.signed_url,
            alt_text: image.alt_text,
            position: image.position,
            primary: image.primary,
            shopify_image_id: image.shopify_image_id
          }
        end
      end
    end
  end
end
