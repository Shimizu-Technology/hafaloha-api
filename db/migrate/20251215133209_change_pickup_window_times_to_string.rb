# frozen_string_literal: true

class ChangePickupWindowTimesToString < ActiveRecord::Migration[8.0]
  def up
    # Change start_time and end_time from time to string to avoid timezone conversion issues
    change_column :acai_pickup_windows, :start_time, :string
    change_column :acai_pickup_windows, :end_time, :string

    # Also change blocked_slots times
    change_column :acai_blocked_slots, :start_time, :string
    change_column :acai_blocked_slots, :end_time, :string
  end

  def down
    change_column :acai_pickup_windows, :start_time, :time
    change_column :acai_pickup_windows, :end_time, :time
    change_column :acai_blocked_slots, :start_time, :time
    change_column :acai_blocked_slots, :end_time, :time
  end
end
