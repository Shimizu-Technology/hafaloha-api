module Api
  module V1
    module Admin
      module Fundraisers
        class ProductsController < BaseController
          before_action :set_fundraiser
          before_action :set_fundraiser_product, only: [:show, :update, :destroy]

          # GET /api/v1/admin/fundraisers/:fundraiser_id/products
          def index
            @fundraiser_products = @fundraiser.fundraiser_products
                                              .includes(product: [:product_images, :product_variants])
                                              .by_position

            # Filter by active status
            @fundraiser_products = @fundraiser_products.active if params[:active] == 'true'

            render json: {
              products: @fundraiser_products.map { |fp| serialize_fundraiser_product(fp) }
            }
          end

          # GET /api/v1/admin/fundraisers/:fundraiser_id/products/:id
          def show
            render json: { product: serialize_fundraiser_product_full(@fundraiser_product) }
          end

          # POST /api/v1/admin/fundraisers/:fundraiser_id/products
          def create
            @fundraiser_product = @fundraiser.fundraiser_products.new(fundraiser_product_params)

            # Set default price from product if not provided
            if @fundraiser_product.price_cents.nil? && @fundraiser_product.product
              @fundraiser_product.price_cents = @fundraiser_product.product.base_price_cents
            end

            # Set default position
            if @fundraiser_product.position.nil?
              max_position = @fundraiser.fundraiser_products.maximum(:position) || 0
              @fundraiser_product.position = max_position + 1
            end

            if @fundraiser_product.save
              render json: { product: serialize_fundraiser_product(@fundraiser_product) }, status: :created
            else
              render json: { errors: @fundraiser_product.errors.full_messages }, status: :unprocessable_entity
            end
          end

          # PUT /api/v1/admin/fundraisers/:fundraiser_id/products/:id
          def update
            if @fundraiser_product.update(fundraiser_product_params)
              render json: { product: serialize_fundraiser_product(@fundraiser_product) }
            else
              render json: { errors: @fundraiser_product.errors.full_messages }, status: :unprocessable_entity
            end
          end

          # DELETE /api/v1/admin/fundraisers/:fundraiser_id/products/:id
          def destroy
            @fundraiser_product.destroy
            render json: { message: 'Product removed from fundraiser' }
          end

          # POST /api/v1/admin/fundraisers/:fundraiser_id/products/reorder
          def reorder
            product_ids = params[:product_ids] || []
            
            product_ids.each_with_index do |id, index|
              @fundraiser.fundraiser_products.where(id: id).update_all(position: index)
            end

            render json: { message: 'Products reordered successfully' }
          end

          # GET /api/v1/admin/fundraisers/:fundraiser_id/products/available
          # Returns products NOT yet added to this fundraiser
          def available
            existing_product_ids = @fundraiser.fundraiser_products.pluck(:product_id)
            
            @products = Product.published.active
                               .where.not(id: existing_product_ids)
                               .includes(:product_images)
                               .order(:name)

            # Search
            if params[:search].present?
              @products = @products.where('name ILIKE ?', "%#{params[:search]}%")
            end

            # Pagination
            page = params[:page]&.to_i || 1
            per_page = [params[:per_page]&.to_i || 20, 50].min
            total = @products.count
            @products = @products.limit(per_page).offset((page - 1) * per_page)

            render json: {
              products: @products.map { |p| serialize_available_product(p) },
              meta: {
                page: page,
                per_page: per_page,
                total: total
              }
            }
          end

          private

          def set_fundraiser
            @fundraiser = Fundraiser.find_by(id: params[:fundraiser_id]) || 
                          Fundraiser.find_by(slug: params[:fundraiser_id])
            render json: { error: 'Fundraiser not found' }, status: :not_found unless @fundraiser
          end

          def set_fundraiser_product
            @fundraiser_product = @fundraiser.fundraiser_products
                                             .includes(product: [:product_images, :product_variants])
                                             .find_by(id: params[:id])
            render json: { error: 'Product not found in fundraiser' }, status: :not_found unless @fundraiser_product
          end

          def fundraiser_product_params
            params.require(:fundraiser_product).permit(
              :product_id, :price_cents, :position, :active, :min_quantity, :max_quantity
            )
          end

          def serialize_fundraiser_product(fp)
            product = fp.product
            {
              id: fp.id,
              product_id: product.id,
              name: product.name,
              slug: product.slug,
              price_cents: fp.price_cents,
              original_price_cents: product.base_price_cents,
              position: fp.position,
              active: fp.active,
              min_quantity: fp.min_quantity,
              max_quantity: fp.max_quantity,
              image_url: product.primary_image&.signed_url,
              variant_count: product.product_variants.count,
              in_stock: product.in_stock?
            }
          end

          def serialize_fundraiser_product_full(fp)
            product = fp.product
            serialize_fundraiser_product(fp).merge(
              description: product.description,
              variants: product.product_variants.map do |v|
                {
                  id: v.id,
                  display_name: v.display_name,
                  size: v.size,
                  color: v.color,
                  sku: v.sku,
                  price_cents: v.price_cents,
                  stock_quantity: v.stock_quantity,
                  in_stock: v.in_stock?
                }
              end
            )
          end

          def serialize_available_product(product)
            {
              id: product.id,
              name: product.name,
              slug: product.slug,
              base_price_cents: product.base_price_cents,
              image_url: product.primary_image&.signed_url,
              product_type: product.product_type,
              in_stock: product.in_stock?
            }
          end
        end
      end
    end
  end
end
