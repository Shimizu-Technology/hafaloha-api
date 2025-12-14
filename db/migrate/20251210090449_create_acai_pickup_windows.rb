class CreateAcaiPickupWindows < ActiveRecord::Migration[8.1]
  def change
    create_table :acai_pickup_windows do |t|
      t.integer :day_of_week
      t.time :start_time
      t.time :end_time
      t.boolean :active
      t.integer :capacity

      t.timestamps
    end
  end
end
