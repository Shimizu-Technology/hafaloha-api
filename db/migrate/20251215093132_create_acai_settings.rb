class CreateAcaiSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :acai_settings do |t|
      t.string :name, default: 'Heart-Shaped Açaí Cake', null: false
      t.text :description
      t.integer :base_price_cents, default: 4500, null: false  # $45.00
      t.string :image_url
      t.string :pickup_location, default: '955 Pale San Vitores Rd, Tumon, Blue Lagoon Plaza'
      t.text :pickup_instructions
      t.string :pickup_phone, default: '671-989-3444'
      t.integer :advance_hours, default: 24, null: false  # Must order 24 hours in advance
      t.integer :max_per_slot, default: 5, null: false    # Max orders per time slot
      t.boolean :active, default: true, null: false
      t.boolean :placard_enabled, default: true, null: false
      t.integer :placard_price_cents, default: 0, null: false  # Base price for any placard
      t.text :toppings_info  # "Banana, Strawberry, Blueberry, Mango"

      t.timestamps
    end
  end
end
