class AddLowStockThresholdToProductVariants < ActiveRecord::Migration[8.1]
  def change
    add_column :product_variants, :low_stock_threshold, :integer, default: 5, null: false
  end
end
