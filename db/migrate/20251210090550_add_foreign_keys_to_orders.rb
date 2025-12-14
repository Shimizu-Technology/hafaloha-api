class AddForeignKeysToOrders < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :orders, :fundraisers, column: :fundraiser_id
    add_foreign_key :orders, :participants, column: :participant_id
    
    add_index :orders, :fundraiser_id
    add_index :orders, :participant_id
  end
end
