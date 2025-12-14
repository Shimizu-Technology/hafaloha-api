class AddCostAndCompareAtPriceToProductVariants < ActiveRecord::Migration[8.1]
  def change
    add_column :product_variants, :cost_cents, :integer
    add_column :product_variants, :compare_at_price_cents, :integer
  end
end
