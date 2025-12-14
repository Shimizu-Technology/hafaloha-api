class AddIsDefaultToProductVariants < ActiveRecord::Migration[8.1]
  def change
    add_column :product_variants, :is_default, :boolean, default: false, null: false
    add_index :product_variants, [:product_id, :is_default]
  end
end
