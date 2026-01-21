# frozen_string_literal: true

class ChangeAcaiPickupTimeToString < ActiveRecord::Migration[8.0]
  def up
    # Change acai_pickup_time from time to string to avoid timezone conversion issues
    # We store it as "HH:MM" or "HH:MM-HH:MM" format
    change_column :orders, :acai_pickup_time, :string
  end

  def down
    # Note: This migration may lose data if there are non-time-formatted strings
    change_column :orders, :acai_pickup_time, :time
  end
end
