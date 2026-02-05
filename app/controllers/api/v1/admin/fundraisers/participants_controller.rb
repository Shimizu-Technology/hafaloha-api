module Api
  module V1
    module Admin
      module Fundraisers
        class ParticipantsController < BaseController
          before_action :set_fundraiser
          before_action :set_participant, only: [ :show, :update, :destroy ]

          # GET /api/v1/admin/fundraisers/:fundraiser_id/participants
          def index
            @participants = @fundraiser.participants

            # Search by name, email, or unique code
            if params[:search].present?
              @participants = @participants.where(
                "name ILIKE ? OR email ILIKE ? OR unique_code ILIKE ?",
                "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%"
              )
            end

            # Filter by active status
            @participants = @participants.active if params[:active] == "true"

            # Order
            @participants = @participants.order(:name)

            # Pagination
            page = params[:page]&.to_i || 1
            per_page = [ params[:per_page]&.to_i || 20, 100 ].min
            total = @participants.count
            @participants = @participants.limit(per_page).offset((page - 1) * per_page)

            render json: {
              participants: @participants.map { |p| serialize_participant(p) },
              meta: {
                page: page,
                per_page: per_page,
                total: total
              }
            }
          end

          # GET /api/v1/admin/fundraisers/:fundraiser_id/participants/:id
          def show
            render json: { participant: serialize_participant_full(@participant) }
          end

          # POST /api/v1/admin/fundraisers/:fundraiser_id/participants
          def create
            @participant = @fundraiser.participants.new(participant_params)
            @participant.active = true if @participant.active.nil?

            if @participant.save
              render json: { participant: serialize_participant(@participant) }, status: :created
            else
              render json: { errors: @participant.errors.full_messages }, status: :unprocessable_entity
            end
          end

          # PUT /api/v1/admin/fundraisers/:fundraiser_id/participants/:id
          def update
            if @participant.update(participant_params)
              render json: { participant: serialize_participant(@participant) }
            else
              render json: { errors: @participant.errors.full_messages }, status: :unprocessable_entity
            end
          end

          # DELETE /api/v1/admin/fundraisers/:fundraiser_id/participants/:id
          def destroy
            if @participant.fundraiser_orders.any?
              render json: { error: "Cannot delete participant with existing orders" }, status: :unprocessable_entity
            else
              @participant.destroy
              render json: { message: "Participant deleted successfully" }
            end
          end

          # POST /api/v1/admin/fundraisers/:fundraiser_id/participants/bulk_create
          def bulk_create
            participants_data = params[:participants] || []
            created = []
            errors = []

            participants_data.each_with_index do |data, index|
              participant = @fundraiser.participants.new(
                name: data[:name],
                email: data[:email],
                phone: data[:phone],
                participant_number: data[:participant_number],
                goal_amount_cents: data[:goal_amount_cents],
                notes: data[:notes],
                active: true
              )

              if participant.save
                created << serialize_participant(participant)
              else
                errors << { index: index, name: data[:name], errors: participant.errors.full_messages }
              end
            end

            render json: {
              created: created,
              errors: errors,
              summary: {
                total: participants_data.length,
                created_count: created.length,
                error_count: errors.length
              }
            }
          end

          # POST /api/v1/admin/fundraisers/:fundraiser_id/participants/bulk_import
          # Import participants from CSV data
          def bulk_import
            csv_data = params[:csv_data]

            unless csv_data.present?
              render json: { error: "CSV data is required" }, status: :unprocessable_entity
              return
            end

            require "csv"
            created = []
            errors = []

            begin
              rows = CSV.parse(csv_data, headers: true)

              rows.each_with_index do |row, index|
                participant = @fundraiser.participants.new(
                  name: row["name"] || row["Name"],
                  email: row["email"] || row["Email"],
                  phone: row["phone"] || row["Phone"],
                  participant_number: row["participant_number"] || row["Number"] || row["#"],
                  goal_amount_cents: parse_goal_amount(row["goal"] || row["Goal"]),
                  notes: row["notes"] || row["Notes"],
                  active: true
                )

                if participant.save
                  created << serialize_participant(participant)
                else
                  errors << { row: index + 2, name: row["name"] || row["Name"], errors: participant.errors.full_messages }
                end
              end
            rescue CSV::MalformedCSVError => e
              render json: { error: "Invalid CSV format: #{e.message}" }, status: :unprocessable_entity
              return
            end

            render json: {
              created: created,
              errors: errors,
              summary: {
                total: created.length + errors.length,
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

          def set_participant
            @participant = @fundraiser.participants.find_by(id: params[:id])
            render json: { error: "Participant not found" }, status: :not_found unless @participant
          end

          def participant_params
            params.require(:participant).permit(
              :name, :email, :phone, :participant_number, :goal_amount_cents, :notes, :active
            )
          end

          def parse_goal_amount(value)
            return nil if value.blank?
            # Handle "$500" or "500.00" or "500"
            clean_value = value.to_s.gsub(/[$,]/, "")
            (clean_value.to_f * 100).to_i
          end

          def serialize_participant(participant)
            {
              id: participant.id,
              name: participant.name,
              email: participant.email,
              phone: participant.phone,
              unique_code: participant.unique_code,
              participant_number: participant.participant_number,
              goal_amount_cents: participant.goal_amount_cents,
              active: participant.active,
              display_name: participant.display_name,
              total_raised_cents: participant.total_raised_cents,
              progress_percentage: participant.progress_percentage,
              order_count: participant.fundraiser_orders.count,
              stats: participant.stats,
              created_at: participant.created_at
            }
          end

          def serialize_participant_full(participant)
            serialize_participant(participant).merge(
              notes: participant.notes,
              fundraiser_id: participant.fundraiser_id,
              fundraiser_name: participant.fundraiser.name,
              recent_orders: participant.fundraiser_orders.recent.limit(5).map { |o| serialize_order_summary(o) },
              updated_at: participant.updated_at
            )
          end

          def serialize_order_summary(order)
            {
              id: order.id,
              order_number: order.order_number,
              status: order.status,
              payment_status: order.payment_status,
              total_cents: order.total_cents,
              customer_name: order.customer_name,
              created_at: order.created_at
            }
          end
        end
      end
    end
  end
end
