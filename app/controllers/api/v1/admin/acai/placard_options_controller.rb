# frozen_string_literal: true

module Api
  module V1
    module Admin
      module Acai
        class PlacardOptionsController < Admin::BaseController
          before_action :set_placard_option, only: [:show, :update, :destroy]

          # GET /api/v1/admin/acai/placard_options
          def index
            options = AcaiPlacardOption.ordered
            render json: {
              success: true,
              data: options.map { |opt| option_json(opt) }
            }
          end

          # GET /api/v1/admin/acai/placard_options/:id
          def show
            render json: {
              success: true,
              data: option_json(@placard_option)
            }
          end

          # POST /api/v1/admin/acai/placard_options
          def create
            @placard_option = AcaiPlacardOption.new(placard_option_params)
            @placard_option.position ||= AcaiPlacardOption.maximum(:position).to_i + 1

            if @placard_option.save
              render json: {
                success: true,
                data: option_json(@placard_option),
                message: 'Placard option created successfully'
              }, status: :created
            else
              render json: {
                success: false,
                errors: @placard_option.errors.full_messages
              }, status: :unprocessable_entity
            end
          end

          # PUT /api/v1/admin/acai/placard_options/:id
          def update
            if @placard_option.update(placard_option_params)
              render json: {
                success: true,
                data: option_json(@placard_option),
                message: 'Placard option updated successfully'
              }
            else
              render json: {
                success: false,
                errors: @placard_option.errors.full_messages
              }, status: :unprocessable_entity
            end
          end

          # DELETE /api/v1/admin/acai/placard_options/:id
          def destroy
            @placard_option.destroy
            render json: {
              success: true,
              message: 'Placard option deleted successfully'
            }
          end

          private

          def set_placard_option
            @placard_option = AcaiPlacardOption.find(params[:id])
          end

          def placard_option_params
            params.require(:placard_option).permit(:name, :description, :price_cents, :available, :position)
          end

          def option_json(opt)
            {
              id: opt.id,
              name: opt.name,
              description: opt.description,
              price_cents: opt.price_cents,
              formatted_price: opt.formatted_price,
              available: opt.available,
              position: opt.position,
              created_at: opt.created_at,
              updated_at: opt.updated_at
            }
          end
        end
      end
    end
  end
end
