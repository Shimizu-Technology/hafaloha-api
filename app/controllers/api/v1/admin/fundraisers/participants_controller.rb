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

            # Search by name or email
            if params[:search].present?
              @participants = @participants.where(
                "name ILIKE ? OR email ILIKE ?",
                "%#{params[:search]}%", "%#{params[:search]}%"
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
            if @participant.orders.any?
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
              :name, :email, :phone, :participant_number, :notes, :active
            )
          end

          def serialize_participant(participant)
            {
              id: participant.id,
              name: participant.name,
              email: participant.email,
              phone: participant.phone,
              participant_number: participant.participant_number,
              active: participant.active,
              display_name: participant.display_name,
              total_raised_cents: participant.total_raised_cents,
              order_count: participant.orders.count,
              created_at: participant.created_at
            }
          end

          def serialize_participant_full(participant)
            serialize_participant(participant).merge(
              notes: participant.notes,
              fundraiser_id: participant.fundraiser_id,
              fundraiser_name: participant.fundraiser.name,
              updated_at: participant.updated_at
            )
          end
        end
      end
    end
  end
end
