class MakeUserIdOptionalOnOrders < ActiveRecord::Migration[8.1]
  def change
    change_column_null :orders, :user_id, true
  end
end
