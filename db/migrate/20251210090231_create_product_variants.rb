class CreateProductVariants < ActiveRecord::Migration[8.1]
  def change
    create_table :product_variants do |t|
      t.references :product, null: false, foreign_key: true
      t.string :size
      t.string :color
      t.string :variant_key
      t.string :variant_name
      t.string :sku
      t.integer :price_cents
      t.integer :stock_quantity
      t.boolean :available
      t.decimal :weight_oz
      t.string :shopify_variant_id
      t.string :barcode

      t.timestamps
    end
    add_index :product_variants, :sku, unique: true
  end
end
