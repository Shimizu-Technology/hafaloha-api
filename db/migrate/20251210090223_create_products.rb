class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name
      t.string :slug
      t.text :description
      t.integer :base_price_cents
      t.string :sku_prefix
      t.boolean :track_inventory
      t.decimal :weight_oz
      t.boolean :published
      t.boolean :featured
      t.string :product_type
      t.string :shopify_product_id
      t.string :vendor
      t.string :meta_title
      t.text :meta_description

      t.timestamps
    end
    add_index :products, :slug, unique: true
  end
end
