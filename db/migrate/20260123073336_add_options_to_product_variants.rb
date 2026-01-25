class AddOptionsToProductVariants < ActiveRecord::Migration[8.1]
  def change
    add_column :product_variants, :options, :jsonb, default: {}, null: false
    add_index :product_variants, :options, using: :gin
  end
end
