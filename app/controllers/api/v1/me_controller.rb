class Api::V1::MeController < ApplicationController
  include Authenticatable

  def show
    render json: {
      id: current_user.id,
      clerk_id: current_user.clerk_id,
      email: current_user.email,
      admin: current_user.admin?
    }
  end
end
