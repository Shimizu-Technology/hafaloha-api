module Api
  module V1
    module Admin
      module Fundraisers
        class ProductsController < BaseController
          before_action :set_fundraiser
          before_action :set_fundraiser_product, only: [ :show, :update, :destroy ]

          # GET /api/v1/admin/fundraisers/:fundraiser_id/products
          def index
            @products = @fundraiser.fundraiser_products
                                   .includes(:fundraiser_product_images, :fundraiser_product_variants)
                                   .order(:position)

            # Filter by published status
            @products = @products.published if params[:published] == "true"

            # Search by name
            if params[:search].present?
              @products = @products.where("name ILIKE ?", "%#{params[:search]}%")
            end

            # Pagination
            page = params[:page]&.to_i || 1
            per_page = [ params[:per_page]&.to_i || 20, 50 ].min
            total = @products.count
            @products = @products.limit(per_page).offset((page - 1) * per_page)

            render json: {
              products: @products.map { |p| serialize_product(p) },
              meta: {
                page: page,
                per_page: per_page,
                total: total
              }
            }
          end

          # GET /api/v1/admin/fundraisers/:fundraiser_id/products/:id
          def show
            render json: { product: serialize_product_full(@fundraiser_product) }
          end

          # POST /api/v1/admin/fundraisers/:fundraiser_id/products
          def create
            @fundraiser_product = @fundraiser.fundraiser_products.new(product_params)

            # Set default position
            if @fundraiser_product.position.nil?
              max_position = @fundraiser.fundraiser_products.maximum(:position) || 0
              @fundraiser_product.position = max_position + 1
            end

            if @fundraiser_product.save
              render json: { product: serialize_product_full(@fundraiser_product) }, status: :created
            else
              render json: { errors: @fundraiser_product.errors.full_messages }, status: :unprocessable_entity
            end
          end

          # PUT /api/v1/admin/fundraisers/:fundraiser_id/products/:id
          def update
            if @fundraiser_product.update(product_params)
              render json: { product: serialize_product_full(@fundraiser_product) }
            else
              render json: { errors: @fundraiser_product.errors.full_messages }, status: :unprocessable_entity
            end
          end

          # DELETE /api/v1/admin/fundraisers/:fundraiser_id/products/:id
          def destroy
            # Check for existing orders with this product's variants
            if FundraiserOrderItem.joins(:fundraiser_product_variant)
                                  .where(fundraiser_product_variants: { fundraiser_product_id: @fundraiser_product.id })
                                  .exists?
              render json: { error: "Cannot delete product with existing orders" }, status: :unprocessable_entity
              return
            end

            @fundraiser_product.destroy
            render json: { message: "Product deleted successfully" }
          end

          # POST /api/v1/admin/fundraisers/:fundraiser_id/products/reorder
          def reorder
            product_ids = params[:product_ids] || []

            product_ids.each_with_index do |id, index|
              @fundraiser.fundraiser_products.where(id: id).update_all(position: index)
            end

            render json: { message: "Products reordered successfully" }
          end

          private

          def set_fundraiser
            @fundraiser = Fundraiser.find_by(id: params[:fundraiser_id]) ||
                          Fundraiser.find_by(slug: params[:fundraiser_id])
            render json: { error: "Fundraiser not found" }, status: :not_found unless @fundraiser
          end

          def set_fundraiser_product
            @fundraiser_product = @fundraiser.fundraiser_products
                                             .includes(:fundraiser_product_images, :fundraiser_product_variants)
                                             .find_by(id: params[:id])
            render json: { error: "Product not found" }, status: :not_found unless @fundraiser_product
          end

          def product_params
            params.require(:product).permit(
              :name, :slug, :description, :base_price_cents,
              :inventory_level, :product_stock_quantity,
              :featured, :published, :sku_prefix, :weight_oz, :position
            )
          end

          def serialize_product(product)
            {
              id: product.id,
              fundraiser_id: product.fundraiser_id,
              name: product.name,
              slug: product.slug,
              base_price_cents: product.base_price_cents,
              inventory_level: product.inventory_level,
              product_stock_quantity: product.product_stock_quantity,
              featured: product.featured,
              published: product.published,
              position: product.position,
              image_url: product.primary_image&.url,
              variant_count: product.fundraiser_product_variants.count,
              in_stock: product.in_stock?,
              created_at: product.created_at
            }
          end

          def serialize_product_full(product)
            serialize_product(product).merge(
              description: product.description,
              sku_prefix: product.sku_prefix,
              weight_oz: product.weight_oz,
              variants: product.fundraiser_product_variants.map { |v| serialize_variant(v) },
              images: product.fundraiser_product_images.order(:position).map { |i| serialize_image(i) },
              updated_at: product.updated_at
            )
          end

          def serialize_variant(variant)
            {
              id: variant.id,
              sku: variant.sku,
              variant_name: variant.variant_name,
              variant_key: variant.variant_key,
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
              in_stock: variant.in_stock?
            }
          end

          def serialize_image(image)
            {
              id: image.id,
              s3_key: image.s3_key,
              url: image.url,
              alt_text: image.alt_text,
              position: image.position,
              primary: image.primary
            }
          end
        end
      end
    end
  end
end
