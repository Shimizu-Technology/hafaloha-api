# frozen_string_literal: true

module Api
  module V1
    module Admin
      module Acai
        class CrustOptionsController < Admin::BaseController
          before_action :set_crust_option, only: [:show, :update, :destroy]

          # GET /api/v1/admin/acai/crust_options
          def index
            options = AcaiCrustOption.ordered
            render json: {
              success: true,
              data: options.map { |opt| option_json(opt) }
            }
          end

          # GET /api/v1/admin/acai/crust_options/:id
          def show
            render json: {
              success: true,
              data: option_json(@crust_option)
            }
          end

          # POST /api/v1/admin/acai/crust_options
          def create
            @crust_option = AcaiCrustOption.new(crust_option_params)

            # Set position to end if not specified
            @crust_option.position ||= AcaiCrustOption.maximum(:position).to_i + 1

            if @crust_option.save
              render json: {
                success: true,
                data: option_json(@crust_option),
                message: 'Crust option created successfully'
              }, status: :created
            else
              render json: {
                success: false,
                errors: @crust_option.errors.full_messages
              }, status: :unprocessable_entity
            end
          end

          # PUT /api/v1/admin/acai/crust_options/:id
          def update
            if @crust_option.update(crust_option_params)
              render json: {
                success: true,
                data: option_json(@crust_option),
                message: 'Crust option updated successfully'
              }
            else
              render json: {
                success: false,
                errors: @crust_option.errors.full_messages
              }, status: :unprocessable_entity
            end
          end

          # DELETE /api/v1/admin/acai/crust_options/:id
          def destroy
            @crust_option.destroy
            render json: {
              success: true,
              message: 'Crust option deleted successfully'
            }
          end

          private

          def set_crust_option
            @crust_option = AcaiCrustOption.find(params[:id])
          end

          def crust_option_params
            params.require(:crust_option).permit(:name, :description, :price_cents, :available, :position)
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
