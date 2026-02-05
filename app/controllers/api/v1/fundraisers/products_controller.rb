module Api
  module V1
    module Fundraisers
      class ProductsController < ApplicationController
        before_action :set_fundraiser
        before_action :set_product, only: [ :show ]

        # GET /api/v1/fundraisers/:fundraiser_slug/products
        def index
          @products = @fundraiser.fundraiser_products
                                 .published
                                 .includes(:fundraiser_product_images, :fundraiser_product_variants)
                                 .order(:position)

          render json: {
            products: @products.map { |p| serialize_product(p) }
          }
        end

        # GET /api/v1/fundraisers/:fundraiser_slug/products/:id
        def show
          render json: { product: serialize_product_detail(@product) }
        end

        private

        def set_fundraiser
          @fundraiser = Fundraiser.published.find_by(slug: params[:fundraiser_slug])

          unless @fundraiser&.status&.in?(%w[active completed])
            render json: { error: "Fundraiser not found" }, status: :not_found
          end
        end

        def set_product
          @product = @fundraiser.fundraiser_products
                                .published
                                .includes(:fundraiser_product_images, :fundraiser_product_variants)
                                .find_by(id: params[:id]) ||
                    @fundraiser.fundraiser_products
                               .published
                               .includes(:fundraiser_product_images, :fundraiser_product_variants)
                               .find_by(slug: params[:id])

          render json: { error: "Product not found" }, status: :not_found unless @product
        end

        def serialize_product(product)
          {
            id: product.id,
            name: product.name,
            slug: product.slug,
            description: product.description&.truncate(200),
            base_price_cents: product.base_price_cents,
            featured: product.featured,
            image_url: product.primary_image&.url,
            variant_count: product.fundraiser_product_variants.available.count,
            in_stock: product.in_stock?
          }
        end

        def serialize_product_detail(product)
          {
            id: product.id,
            name: product.name,
            slug: product.slug,
            description: product.description,
            base_price_cents: product.base_price_cents,
            inventory_level: product.inventory_level,
            featured: product.featured,
            images: product.fundraiser_product_images.order(:position).map do |img|
              {
                id: img.id,
                url: img.url,
                alt_text: img.alt_text,
                primary: img.primary,
                position: img.position
              }
            end,
            variants: product.fundraiser_product_variants.available.map do |v|
              {
                id: v.id,
                display_name: v.display_name,
                variant_name: v.variant_name,
                variant_key: v.variant_key,
                size: v.size,
                color: v.color,
                material: v.material,
                options: v.options,
                sku: v.sku,
                price_cents: v.price_cents,
                compare_at_price_cents: v.compare_at_price_cents,
                in_stock: v.in_stock?,
                actually_available: v.actually_available?,
                is_default: v.is_default
              }
            end,
            in_stock: product.in_stock?,
            actually_available: product.actually_available?
          }
        end
      end
    end
  end
end
