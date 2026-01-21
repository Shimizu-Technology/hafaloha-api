class CreateAcaiCrustOptions < ActiveRecord::Migration[8.1]
  def change
    create_table :acai_crust_options do |t|
      t.string :name, null: false
      t.string :description
      t.integer :price_cents, default: 0, null: false
      t.boolean :available, default: true, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :acai_crust_options, :available
    add_index :acai_crust_options, :position
  end
end
