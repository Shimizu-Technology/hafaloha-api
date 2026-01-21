# frozen_string_literal: true

module Api
  module V1
    module Admin
      module Acai
        class BlockedSlotsController < Admin::BaseController
          before_action :set_blocked_slot, only: [:show, :update, :destroy]

          # GET /api/v1/admin/acai/blocked_slots
          def index
            slots = AcaiBlockedSlot.upcoming.recent
            render json: {
              success: true,
              data: slots.map { |s| slot_json(s) }
            }
          end

          # GET /api/v1/admin/acai/blocked_slots/:id
          def show
            render json: {
              success: true,
              data: slot_json(@blocked_slot)
            }
          end

          # POST /api/v1/admin/acai/blocked_slots
          def create
            @blocked_slot = AcaiBlockedSlot.new(blocked_slot_params)

            if @blocked_slot.save
              render json: {
                success: true,
                data: slot_json(@blocked_slot),
                message: 'Blocked slot created successfully'
              }, status: :created
            else
              render json: {
                success: false,
                errors: @blocked_slot.errors.full_messages
              }, status: :unprocessable_entity
            end
          end

          # PUT /api/v1/admin/acai/blocked_slots/:id
          def update
            if @blocked_slot.update(blocked_slot_params)
              render json: {
                success: true,
                data: slot_json(@blocked_slot),
                message: 'Blocked slot updated successfully'
              }
            else
              render json: {
                success: false,
                errors: @blocked_slot.errors.full_messages
              }, status: :unprocessable_entity
            end
          end

          # DELETE /api/v1/admin/acai/blocked_slots/:id
          def destroy
            @blocked_slot.destroy
            render json: {
              success: true,
              message: 'Blocked slot deleted successfully'
            }
          end

          private

          def set_blocked_slot
            @blocked_slot = AcaiBlockedSlot.find(params[:id])
          end

          def blocked_slot_params
            params.require(:blocked_slot).permit(:blocked_date, :start_time, :end_time, :reason)
          end

          def slot_json(s)
            {
              id: s.id,
              blocked_date: s.blocked_date.to_s,
              start_time: s.start_time_hhmm,
              end_time: s.end_time_hhmm,
              reason: s.reason,
              display_name: s.display_name,
              created_at: s.created_at,
              updated_at: s.updated_at
            }
          end
        end
      end
    end
  end
end
