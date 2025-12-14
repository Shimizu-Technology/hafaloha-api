class HealthController < ApplicationController
  def show
    render json: {
      status: 'ok',
      timestamp: Time.current,
      environment: Rails.env,
      database: database_status,
      version: '1.0.0'
    }
  end

  private

  def database_status
    ActiveRecord::Base.connection.active? ? 'connected' : 'disconnected'
  rescue
    'error'
  end
end

