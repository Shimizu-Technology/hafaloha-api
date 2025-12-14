# frozen_string_literal: true

module Api
  module V1
    module Admin
      class SettingsController < ApplicationController
        include Authenticatable
        before_action :require_admin!

        # GET /api/v1/admin/settings
        def show
          settings = SiteSetting.instance
          
          render json: {
            settings: {
              payment_test_mode: settings.payment_test_mode,
              payment_processor: settings.payment_processor,
              send_customer_emails: settings.send_customer_emails,
              store_name: settings.store_name,
              store_email: settings.store_email,
              store_phone: settings.store_phone,
              order_notification_emails: settings.order_notification_emails,
              shipping_origin_address: settings.shipping_origin_address
            }
          }
        end

        # PUT /api/v1/admin/settings
        def update
          settings = SiteSetting.instance
          
          if settings.update(settings_params)
            render json: {
              success: true,
              message: 'Settings updated successfully',
              settings: {
                payment_test_mode: settings.payment_test_mode,
                payment_processor: settings.payment_processor,
                send_customer_emails: settings.send_customer_emails,
                store_name: settings.store_name,
                store_email: settings.store_email,
                store_phone: settings.store_phone,
                order_notification_emails: settings.order_notification_emails,
                shipping_origin_address: settings.shipping_origin_address
              }
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
            :payment_test_mode,
            :payment_processor,
            :send_customer_emails,
            :store_name,
            :store_email,
            :store_phone,
            order_notification_emails: [],
            shipping_origin_address: [
              :company, :street1, :street2, :city, :state, :zip, :country, :phone
            ]
          )
        end
      end
    end
  end
end

