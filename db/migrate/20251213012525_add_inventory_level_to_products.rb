class AddInventoryLevelToProducts < ActiveRecord::Migration[8.1]
  def change
    # Add inventory_level enum (none, product, variant)
    add_column :products, :inventory_level, :string, default: 'none', null: false
    
    # Add product-level inventory fields
    add_column :products, :product_stock_quantity, :integer
    add_column :products, :product_low_stock_threshold, :integer, default: 5
    
    # Migrate existing data: track_inventory true -> variant, false -> none
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE products 
          SET inventory_level = CASE 
            WHEN track_inventory = true THEN 'variant'
            ELSE 'none'
          END
        SQL
      end
    end
    
    # Keep track_inventory for now for backward compatibility
    # We can remove it in a future migration after confirming everything works
  end
end
