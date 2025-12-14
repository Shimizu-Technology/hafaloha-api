class CreateImports < ActiveRecord::Migration[8.1]
  def change
    create_table :imports do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: 'pending' # pending, processing, completed, failed
      t.string :filename
      t.string :inventory_filename
      t.integer :products_count, default: 0
      t.integer :variants_count, default: 0
      t.integer :images_count, default: 0
      t.integer :collections_count, default: 0
      t.integer :skipped_count, default: 0
      t.text :error_messages
      t.text :warnings
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end
    
    add_index :imports, :status
    add_index :imports, :created_at
  end
end
