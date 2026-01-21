class ChangeProductIdNullableOnOrderItems < ActiveRecord::Migration[8.1]
  def change
    # Allow null product_id for Acai orders (which don't reference products)
    change_column_null :order_items, :product_id, true
    change_column_null :order_items, :product_variant_id, true
  end
end
