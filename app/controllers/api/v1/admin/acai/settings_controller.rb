# frozen_string_literal: true

module Api
  module V1
    module Admin
      module Acai
        class SettingsController < Admin::BaseController
          # GET /api/v1/admin/acai/settings
          def show
            settings = AcaiSetting.instance
            render json: {
              success: true,
              data: settings_json(settings)
            }
          end

          # PUT /api/v1/admin/acai/settings
          def update
            settings = AcaiSetting.instance

            if settings.update(settings_params)
              render json: {
                success: true,
                data: settings_json(settings),
                message: 'Acai settings updated successfully'
              }
            else
              render json: {
                success: false,
                errors: settings.errors.full_messages
              }, status: :unprocessable_entity
            end
          end

          private

          def settings_params
            params.require(:settings).permit(
              :name, :description, :base_price_cents, :image_url,
              :pickup_location, :pickup_instructions, :pickup_phone,
              :advance_hours, :max_per_slot, :active,
              :placard_enabled, :placard_price_cents, :toppings_info
            )
          end

          def settings_json(settings)
            {
              id: settings.id,
              name: settings.name,
              description: settings.description,
              base_price_cents: settings.base_price_cents,
              formatted_price: settings.formatted_price,
              image_url: settings.image_url,
              pickup_location: settings.pickup_location,
              pickup_instructions: settings.pickup_instructions,
              pickup_phone: settings.pickup_phone,
              advance_hours: settings.advance_hours,
              max_per_slot: settings.max_per_slot,
              active: settings.active,
              placard_enabled: settings.placard_enabled,
              placard_price_cents: settings.placard_price_cents,
              toppings_info: settings.toppings_info,
              ordering_enabled: settings.ordering_enabled?,
              updated_at: settings.updated_at
            }
          end
        end
      end
    end
  end
end
