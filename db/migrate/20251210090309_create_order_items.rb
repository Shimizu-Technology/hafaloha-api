class CreateOrderItems < ActiveRecord::Migration[8.1]
  def change
    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :product_variant, null: false, foreign_key: true
      t.integer :quantity
      t.integer :unit_price_cents
      t.integer :total_price_cents
      t.string :product_name
      t.string :variant_name
      t.string :product_sku

      t.timestamps
    end
  end
end
