class CreateAcaiBlockedSlots < ActiveRecord::Migration[8.1]
  def change
    create_table :acai_blocked_slots do |t|
      t.date :blocked_date
      t.time :start_time
      t.time :end_time
      t.string :reason

      t.timestamps
    end
  end
end
