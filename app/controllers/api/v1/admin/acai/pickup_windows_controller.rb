# frozen_string_literal: true

module Api
  module V1
    module Admin
      module Acai
        class PickupWindowsController < Admin::BaseController
          before_action :set_pickup_window, only: [ :show, :update, :destroy ]

          # GET /api/v1/admin/acai/pickup_windows
          def index
            windows = AcaiPickupWindow.by_day
            render json: {
              success: true,
              data: windows.map { |w| window_json(w) }
            }
          end

          # GET /api/v1/admin/acai/pickup_windows/:id
          def show
            render json: {
              success: true,
              data: window_json(@pickup_window)
            }
          end

          # POST /api/v1/admin/acai/pickup_windows
          def create
            @pickup_window = AcaiPickupWindow.new(pickup_window_params)

            if @pickup_window.save
              render json: {
                success: true,
                data: window_json(@pickup_window),
                message: "Pickup window created successfully"
              }, status: :created
            else
              render json: {
                success: false,
                errors: @pickup_window.errors.full_messages
              }, status: :unprocessable_entity
            end
          end

          # PUT /api/v1/admin/acai/pickup_windows/:id
          def update
            if @pickup_window.update(pickup_window_params)
              render json: {
                success: true,
                data: window_json(@pickup_window),
                message: "Pickup window updated successfully"
              }
            else
              render json: {
                success: false,
                errors: @pickup_window.errors.full_messages
              }, status: :unprocessable_entity
            end
          end

          # DELETE /api/v1/admin/acai/pickup_windows/:id
          def destroy
            @pickup_window.destroy
            render json: {
              success: true,
              message: "Pickup window deleted successfully"
            }
          end

          private

          def set_pickup_window
            @pickup_window = AcaiPickupWindow.find(params[:id])
          end

          def pickup_window_params
            params.require(:pickup_window).permit(:day_of_week, :start_time, :end_time, :capacity, :active)
          end

          def window_json(w)
            {
              id: w.id,
              day_of_week: w.day_of_week,
              day_name: w.day_name,
              start_time: w.start_time_hhmm,
              end_time: w.end_time_hhmm,
              capacity: w.capacity,
              active: w.active,
              display_name: w.display_name,
              created_at: w.created_at,
              updated_at: w.updated_at
            }
          end
        end
      end
    end
  end
end
