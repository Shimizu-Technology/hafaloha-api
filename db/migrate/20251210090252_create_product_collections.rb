class CreateProductCollections < ActiveRecord::Migration[8.1]
  def change
    create_table :product_collections do |t|
      t.references :product, null: false, foreign_key: true
      t.references :collection, null: false, foreign_key: true
      t.integer :position

      t.timestamps
    end
  end
end
