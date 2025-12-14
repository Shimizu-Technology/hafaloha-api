class CreateProductImages < ActiveRecord::Migration[8.1]
  def change
    create_table :product_images do |t|
      t.references :product, null: false, foreign_key: true
      t.string :url
      t.string :alt_text
      t.integer :position
      t.boolean :primary
      t.string :shopify_image_id

      t.timestamps
    end
  end
end
