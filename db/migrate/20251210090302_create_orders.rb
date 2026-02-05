class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.string :order_number
      t.references :user, null: false, foreign_key: true
      t.string :order_type # 'retail', 'wholesale', 'acai'
      t.string :customer_name
      t.string :customer_email
      t.string :customer_phone

      # Pricing
      t.integer :subtotal_cents
      t.integer :shipping_cost_cents
      t.integer :tax_cents
      t.integer :total_cents

      # Status
      t.string :status # 'pending', 'processing', 'shipped', 'delivered', 'cancelled'
      t.string :payment_status # 'pending', 'paid', 'failed', 'refunded'
      t.string :payment_intent_id

      # Shipping
      t.string :shipping_method
      t.string :tracking_number
      t.string :shipping_address_line1
      t.string :shipping_address_line2
      t.string :shipping_city
      t.string :shipping_state
      t.string :shipping_zip
      t.string :shipping_country
      t.string :easypost_shipment_id

      # Wholesale (fundraiser orders) - references added separately
      t.bigint :fundraiser_id, null: true
      t.bigint :participant_id, null: true

      # Acai Cakes
      t.date :acai_pickup_date
      t.time :acai_pickup_time
      t.string :acai_crust_type
      t.boolean :acai_include_placard
      t.string :acai_placard_text

      # Admin notes
      t.text :notes
      t.text :admin_notes

      t.timestamps
    end

    add_index :orders, :order_number, unique: true
    add_index :orders, :status
    add_index :orders, :order_type
  end
end
