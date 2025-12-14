class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :clerk_id
      t.string :email
      t.string :name
      t.string :phone
      t.string :role

      t.timestamps
    end
    add_index :users, :clerk_id, unique: true
  end
end
