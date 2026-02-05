module Api
  module V1
    class FundraisersController < ApplicationController
      before_action :set_fundraiser, only: [ :show, :create_order ]

      # GET /api/v1/fundraisers
      # Public list of active/published fundraisers
      def index
        @fundraisers = Fundraiser.published
                                 .where(status: %w[active completed])
                                 .order(start_date: :desc)

        render json: {
          fundraisers: @fundraisers.map { |f| serialize_fundraiser_public(f) }
        }
      end

      # GET /api/v1/fundraisers/:slug
      # Public fundraiser detail page
      def show
        unless @fundraiser.published? && @fundraiser.status.in?(%w[active completed])
          render json: { error: "Fundraiser not available" }, status: :not_found
          return
        end

        render json: {
          fundraiser: serialize_fundraiser_detail(@fundraiser),
          products: @fundraiser.fundraiser_products.published.by_position.map { |p| serialize_product(p) },
          participants: @fundraiser.participants.active.by_name.map { |p| serialize_participant(p) }
        }
      end

      # POST /api/v1/fundraisers/:slug/create_order (legacy route)
      # Delegates to the Fundraisers::OrdersController
      def create_order
        unless @fundraiser.active?
          return render json: { error: "This fundraiser is no longer accepting orders" }, status: :unprocessable_entity
        end

        # Forward to the new orders controller
        controller = Fundraisers::OrdersController.new
        controller.request = request
        controller.response = response
        controller.params = params.merge(fundraiser_slug: params[:slug])
        controller.process(:create)
      end

      private

      def set_fundraiser
        @fundraiser = Fundraiser.includes(
          :participants,
          fundraiser_products: [ :fundraiser_product_images, :fundraiser_product_variants ]
        ).find_by(slug: params[:slug]) ||
                      Fundraiser.find_by(slug: params[:id]) ||
                      Fundraiser.find_by(id: params[:id])

        render json: { error: "Fundraiser not found" }, status: :not_found unless @fundraiser
      end

      def serialize_fundraiser_public(fundraiser)
        {
          id: fundraiser.id,
          name: fundraiser.name,
          slug: fundraiser.slug,
          organization_name: fundraiser.organization_name,
          description: fundraiser.description&.truncate(200),
          start_date: fundraiser.start_date,
          end_date: fundraiser.end_date,
          image_url: fundraiser.image_url,
          goal_amount_cents: fundraiser.goal_amount_cents,
          raised_amount_cents: fundraiser.raised_amount_cents,
          progress_percentage: fundraiser.progress_percentage,
          is_active: fundraiser.active?,
          is_ended: fundraiser.ended?,
          product_count: fundraiser.fundraiser_products.published.count,
          participant_count: fundraiser.participants.active.count
        }
      end

      def serialize_fundraiser_detail(fundraiser)
        {
          id: fundraiser.id,
          name: fundraiser.name,
          slug: fundraiser.slug,
          organization_name: fundraiser.organization_name,
          description: fundraiser.description,
          public_message: fundraiser.public_message,
          start_date: fundraiser.start_date,
          end_date: fundraiser.end_date,
          image_url: fundraiser.image_url,
          goal_amount_cents: fundraiser.goal_amount_cents,
          raised_amount_cents: fundraiser.raised_amount_cents,
          progress_percentage: fundraiser.progress_percentage,
          contact_name: fundraiser.contact_name,
          contact_email: fundraiser.contact_email,
          contact_phone: fundraiser.contact_phone,
          pickup_location: fundraiser.pickup_location,
          pickup_instructions: fundraiser.pickup_instructions,
          allow_shipping: fundraiser.allow_shipping,
          shipping_note: fundraiser.shipping_note,
          thank_you_message: fundraiser.thank_you_message,
          is_active: fundraiser.active?,
          is_ended: fundraiser.ended?,
          can_order: fundraiser.active?
        }
      end

      def serialize_product(product)
        {
          id: product.id,
          name: product.name,
          slug: product.slug,
          description: product.description,
          base_price_cents: product.base_price_cents,
          inventory_level: product.inventory_level,
          featured: product.featured,
          image_url: product.primary_image&.url,
          images: product.fundraiser_product_images.order(:position).map do |img|
            {
              id: img.id,
              url: img.url,
              alt_text: img.alt_text,
              primary: img.primary
            }
          end,
          variants: product.fundraiser_product_variants.available.map do |v|
            {
              id: v.id,
              display_name: v.display_name,
              variant_name: v.variant_name,
              size: v.size,
              color: v.color,
              material: v.material,
              sku: v.sku,
              price_cents: v.price_cents,
              compare_at_price_cents: v.compare_at_price_cents,
              in_stock: v.in_stock?,
              is_default: v.is_default
            }
          end,
          in_stock: product.in_stock?
        }
      end

      def serialize_participant(participant)
        {
          id: participant.id,
          name: participant.name,
          unique_code: participant.unique_code,
          participant_number: participant.participant_number,
          display_name: participant.display_name,
          goal_amount_cents: participant.goal_amount_cents,
          total_raised_cents: participant.total_raised_cents,
          progress_percentage: participant.progress_percentage
        }
      end
    end
  end
end
