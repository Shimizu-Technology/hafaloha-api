class CreateCartItems < ActiveRecord::Migration[8.1]
  def change
    create_table :cart_items do |t|
      t.references :user, null: false, foreign_key: true
      t.references :product_variant, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.string :session_id # For guest carts (before login)

      t.timestamps
    end

    add_index :cart_items, [:user_id, :product_variant_id], unique: true, where: "user_id IS NOT NULL", name: 'index_cart_items_on_user_and_variant'
    add_index :cart_items, [:session_id, :product_variant_id], unique: true, where: "session_id IS NOT NULL", name: 'index_cart_items_on_session_and_variant'
  end
end
