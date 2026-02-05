module Api
  module V1
    module Admin
      class BaseController < ApplicationController
        include Authenticatable

        before_action :require_admin!

        private

        def render_success(data, message: nil, status: :ok)
          render json: {
            success: true,
            message: message,
            data: data
          }, status: status
        end

        def render_error(message, errors: nil, status: :unprocessable_entity)
          render json: {
            success: false,
            message: message,
            errors: errors
          }, status: status
        end

        def render_created(data, message: "Resource created successfully")
          render_success(data, message: message, status: :created)
        end

        def render_not_found(message = "Resource not found")
          render_error(message, status: :not_found)
        end
      end
    end
  end
end
