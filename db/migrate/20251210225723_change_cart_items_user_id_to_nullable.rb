class ChangeCartItemsUserIdToNullable < ActiveRecord::Migration[8.1]
  def change
    change_column_null :cart_items, :user_id, true
  end
end
