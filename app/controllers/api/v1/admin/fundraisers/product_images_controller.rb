module Api
  module V1
    module Admin
      module Fundraisers
        class ProductImagesController < BaseController
          before_action :set_fundraiser
          before_action :set_product
          before_action :set_image, only: [ :show, :update, :destroy, :set_primary ]

          # GET /api/v1/admin/fundraisers/:fundraiser_id/products/:product_id/images
          def index
            @images = @product.fundraiser_product_images.order(:position)

            render json: {
              images: @images.map { |i| serialize_image(i) }
            }
          end

          # GET /api/v1/admin/fundraisers/:fundraiser_id/products/:product_id/images/:id
          def show
            render json: { image: serialize_image(@image) }
          end

          # POST /api/v1/admin/fundraisers/:fundraiser_id/products/:product_id/images
          def create
            @image = @product.fundraiser_product_images.new(image_params)

            # Set position to end if not specified
            @image.position ||= @product.fundraiser_product_images.maximum(:position).to_i + 1

            # Set as primary if it's the first image
            @image.primary = true if @product.fundraiser_product_images.none?

            if @image.save
              render json: { image: serialize_image(@image) }, status: :created
            else
              render json: { errors: @image.errors.full_messages }, status: :unprocessable_entity
            end
          end

          # PUT /api/v1/admin/fundraisers/:fundraiser_id/products/:product_id/images/:id
          def update
            if @image.update(image_params)
              render json: { image: serialize_image(@image) }
            else
              render json: { errors: @image.errors.full_messages }, status: :unprocessable_entity
            end
          end

          # DELETE /api/v1/admin/fundraisers/:fundraiser_id/products/:product_id/images/:id
          def destroy
            was_primary = @image.primary?
            @image.destroy

            # If deleted image was primary, make another image primary
            if was_primary
              new_primary = @product.fundraiser_product_images.order(:position).first
              new_primary&.update(primary: true)
            end

            render json: { message: "Image deleted successfully" }
          end

          # POST /api/v1/admin/fundraisers/:fundraiser_id/products/:product_id/images/:id/set_primary
          def set_primary
            @image.set_as_primary!
            render json: { image: serialize_image(@image.reload) }
          end

          # POST /api/v1/admin/fundraisers/:fundraiser_id/products/:product_id/images/reorder
          def reorder
            image_ids = params[:image_ids] || []

            FundraiserProductImage.transaction do
              image_ids.each_with_index do |id, index|
                @product.fundraiser_product_images.where(id: id).update_all(position: index)
              end
            end

            render json: { message: "Images reordered successfully" }
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

          def set_image
            @image = @product.fundraiser_product_images.find_by(id: params[:id])
            render json: { error: "Image not found" }, status: :not_found unless @image
          end

          def image_params
            params.require(:image).permit(:s3_key, :alt_text, :position, :primary)
          end

          def serialize_image(image)
            {
              id: image.id,
              fundraiser_product_id: image.fundraiser_product_id,
              s3_key: image.s3_key,
              url: image.url,
              alt_text: image.alt_text,
              position: image.position,
              primary: image.primary,
              created_at: image.created_at
            }
          end
        end
      end
    end
  end
end
