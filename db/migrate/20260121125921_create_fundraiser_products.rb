class CreateFundraiserProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :fundraiser_products do |t|
      t.references :fundraiser, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :price_cents, null: false  # Fundraiser-specific price
      t.integer :position, default: 0
      t.boolean :active, default: true, null: false
      t.integer :min_quantity, default: 1  # Minimum order quantity
      t.integer :max_quantity              # Maximum order quantity (nil = unlimited)

      t.timestamps
    end

    # Prevent duplicate product entries per fundraiser
    add_index :fundraiser_products, [:fundraiser_id, :product_id], unique: true
    add_index :fundraiser_products, [:fundraiser_id, :active]
    add_index :fundraiser_products, [:fundraiser_id, :position]
  end
end
