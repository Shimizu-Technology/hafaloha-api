module Api
  module V1
    module Admin
      class FundraisersController < BaseController
        before_action :set_fundraiser, only: [ :show, :update, :destroy, :stats ]

        # GET /api/v1/admin/fundraisers
        def index
          @fundraisers = Fundraiser.all

          # Filter by status
          @fundraisers = @fundraisers.by_status(params[:status]) if params[:status].present?

          # Filter by published
          @fundraisers = @fundraisers.published if params[:published] == "true"

          # Search by name or organization
          if params[:search].present?
            @fundraisers = @fundraisers.where(
              "name ILIKE ? OR organization_name ILIKE ?",
              "%#{params[:search]}%", "%#{params[:search]}%"
            )
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
          if @fundraiser.fundraiser_orders.any?
            render json: { error: "Cannot delete fundraiser with existing orders" }, status: :unprocessable_entity
          else
            @fundraiser.destroy
            render json: { message: "Fundraiser deleted successfully" }
          end
        end

        # GET /api/v1/admin/fundraisers/:id/stats
        def stats
          render json: {
            fundraiser: {
              id: @fundraiser.id,
              name: @fundraiser.name,
              slug: @fundraiser.slug
            },
            stats: @fundraiser.stats,
            orders_by_status: orders_by_status_stats,
            top_participants: top_participants_stats,
            top_products: top_products_stats,
            daily_revenue: daily_revenue_stats
          }
        end

        private

        def set_fundraiser
          @fundraiser = Fundraiser.find_by(id: params[:id]) || Fundraiser.find_by(slug: params[:id])
          render json: { error: "Fundraiser not found" }, status: :not_found unless @fundraiser
        end

        def fundraiser_params
          params.require(:fundraiser).permit(
            :name, :slug, :description, :organization_name,
            :status, :published, :payout_percentage,
            :start_date, :end_date,
            :goal_amount_cents, :image_url,
            :contact_name, :contact_email, :contact_phone,
            :pickup_location, :pickup_instructions,
            :allow_shipping, :shipping_note,
            :public_message, :thank_you_message
          )
        end

        def orders_by_status_stats
          @fundraiser.fundraiser_orders.group(:status).count
        end

        def top_participants_stats
          @fundraiser.participants
                     .joins(:fundraiser_orders)
                     .where(fundraiser_orders: { payment_status: "paid" })
                     .select("participants.*, SUM(fundraiser_orders.total_cents) as total_raised")
                     .group("participants.id")
                     .order("total_raised DESC")
                     .limit(10)
                     .map do |p|
            {
              id: p.id,
              name: p.name,
              unique_code: p.unique_code,
              total_raised_cents: p.total_raised.to_i
            }
          end
        end

        def top_products_stats
          FundraiserOrderItem.joins(fundraiser_order: :fundraiser, fundraiser_product_variant: :fundraiser_product)
                             .where(fundraiser_orders: { fundraiser_id: @fundraiser.id, payment_status: "paid" })
                             .select("fundraiser_products.id, fundraiser_products.name, SUM(fundraiser_order_items.quantity) as total_sold, SUM(fundraiser_order_items.price_cents * fundraiser_order_items.quantity) as total_revenue")
                             .group("fundraiser_products.id, fundraiser_products.name")
                             .order("total_sold DESC")
                             .limit(10)
                             .map do |item|
            {
              id: item.id,
              name: item.name,
              total_sold: item.total_sold.to_i,
              total_revenue_cents: item.total_revenue.to_i
            }
          end
        end

        def daily_revenue_stats
          @fundraiser.fundraiser_orders
                     .where(payment_status: "paid")
                     .where("created_at >= ?", 30.days.ago)
                     .group("DATE(created_at)")
                     .select("DATE(created_at) as date, COUNT(*) as order_count, SUM(total_cents) as revenue")
                     .order("date ASC")
                     .map do |day|
            {
              date: day.date,
              order_count: day.order_count,
              revenue_cents: day.revenue.to_i
            }
          end
        end

        def serialize_fundraiser(fundraiser)
          {
            id: fundraiser.id,
            name: fundraiser.name,
            slug: fundraiser.slug,
            organization_name: fundraiser.organization_name,
            status: fundraiser.status,
            published: fundraiser.published,
            start_date: fundraiser.start_date,
            end_date: fundraiser.end_date,
            goal_amount_cents: fundraiser.goal_amount_cents,
            raised_amount_cents: fundraiser.raised_amount_cents,
            progress_percentage: fundraiser.progress_percentage,
            payout_percentage: fundraiser.payout_percentage,
            organization_payout_cents: fundraiser.organization_payout_cents,
            image_url: fundraiser.image_url,
            participant_count: fundraiser.participants.count,
            product_count: fundraiser.fundraiser_products.published.count,
            order_count: fundraiser.fundraiser_orders.count,
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
            stats: fundraiser.stats,
            updated_at: fundraiser.updated_at
          )
        end
      end
    end
  end
end
