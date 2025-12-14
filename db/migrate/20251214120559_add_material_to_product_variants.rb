class AddMaterialToProductVariants < ActiveRecord::Migration[8.1]
  def change
    add_column :product_variants, :material, :string
  end
end
