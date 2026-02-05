module Api
  module V1
    module Admin
      class FundraisersController < BaseController
        before_action :set_fundraiser, only: [ :show, :update, :destroy ]

        # GET /api/v1/admin/fundraisers
        def index
          @fundraisers = Fundraiser.all

          # Filter by status
          @fundraisers = @fundraisers.by_status(params[:status]) if params[:status].present?

          # Search by name
          if params[:search].present?
            @fundraisers = @fundraisers.where("name ILIKE ?", "%#{params[:search]}%")
          end

          # Order
          @fundraisers = @fundraisers.order(created_at: :desc)

          # Pagination
          page = params[:page]&.to_i || 1
          per_page = [ params[:per_page]&.to_i || 20, 50 ].min
          total = @fundraisers.count
          @fundraisers = @fundraisers.limit(per_page).offset((page - 1) * per_page)

          render json: {
            fundraisers: @fundraisers.map { |f| serialize_fundraiser(f) },
            meta: {
              page: page,
              per_page: per_page,
              total: total
            }
          }
        end

        # GET /api/v1/admin/fundraisers/:id
        def show
          render json: { fundraiser: serialize_fundraiser_full(@fundraiser) }
        end

        # POST /api/v1/admin/fundraisers
        def create
          @fundraiser = Fundraiser.new(fundraiser_params)
          @fundraiser.status ||= "draft"

          if @fundraiser.save
            render json: { fundraiser: serialize_fundraiser_full(@fundraiser) }, status: :created
          else
            render json: { errors: @fundraiser.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # PUT /api/v1/admin/fundraisers/:id
        def update
          if @fundraiser.update(fundraiser_params)
            render json: { fundraiser: serialize_fundraiser_full(@fundraiser) }
          else
            render json: { errors: @fundraiser.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/admin/fundraisers/:id
        def destroy
          if @fundraiser.orders.any?
            render json: { error: "Cannot delete fundraiser with existing orders" }, status: :unprocessable_entity
          else
            @fundraiser.destroy
            render json: { message: "Fundraiser deleted successfully" }
          end
        end

        private

        def set_fundraiser
          @fundraiser = Fundraiser.find_by(id: params[:id]) || Fundraiser.find_by(slug: params[:id])
          render json: { error: "Fundraiser not found" }, status: :not_found unless @fundraiser
        end

        def fundraiser_params
          params.require(:fundraiser).permit(
            :name, :slug, :description, :status,
            :start_date, :end_date,
            :goal_amount_cents, :image_url,
            :contact_name, :contact_email, :contact_phone,
            :pickup_location, :pickup_instructions,
            :allow_shipping, :shipping_note,
            :public_message, :thank_you_message
          )
        end

        def serialize_fundraiser(fundraiser)
          {
            id: fundraiser.id,
            name: fundraiser.name,
            slug: fundraiser.slug,
            status: fundraiser.status,
            start_date: fundraiser.start_date,
            end_date: fundraiser.end_date,
            goal_amount_cents: fundraiser.goal_amount_cents,
            raised_amount_cents: fundraiser.raised_amount_cents,
            progress_percentage: fundraiser.progress_percentage,
            image_url: fundraiser.image_url,
            participant_count: fundraiser.participants.count,
            product_count: fundraiser.fundraiser_products.active.count,
            order_count: fundraiser.orders.count,
            is_active: fundraiser.active?,
            is_upcoming: fundraiser.upcoming?,
            is_ended: fundraiser.ended?,
            created_at: fundraiser.created_at
          }
        end

        def serialize_fundraiser_full(fundraiser)
          serialize_fundraiser(fundraiser).merge(
            description: fundraiser.description,
            contact_name: fundraiser.contact_name,
            contact_email: fundraiser.contact_email,
            contact_phone: fundraiser.contact_phone,
            pickup_location: fundraiser.pickup_location,
            pickup_instructions: fundraiser.pickup_instructions,
            allow_shipping: fundraiser.allow_shipping,
            shipping_note: fundraiser.shipping_note,
            public_message: fundraiser.public_message,
            thank_you_message: fundraiser.thank_you_message,
            updated_at: fundraiser.updated_at
          )
        end
      end
    end
  end
end
