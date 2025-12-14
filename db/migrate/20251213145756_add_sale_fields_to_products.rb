class AddSaleFieldsToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :sale_price_cents, :integer, default: nil
    add_column :products, :new_product, :boolean, default: false, null: false
  end
end
