class AddMissingIndexes < ActiveRecord::Migration[8.0]
  def change
    # Orders - for searching and filtering
    add_index :orders, :customer_email unless index_exists?(:orders, :customer_email)
    add_index :orders, :created_at unless index_exists?(:orders, :created_at)
    add_index :orders, :payment_status unless index_exists?(:orders, :payment_status)
    
    # Users - for email lookup
    add_index :users, :email unless index_exists?(:users, :email)
  end
end
