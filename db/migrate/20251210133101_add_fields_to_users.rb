class AddFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :admin, :boolean, default: false unless column_exists?(:users, :admin)
    add_index :users, :role unless index_exists?(:users, :role)
  end
end
