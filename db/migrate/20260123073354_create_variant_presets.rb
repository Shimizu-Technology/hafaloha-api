class CreateVariantPresets < ActiveRecord::Migration[8.1]
  def change
    create_table :variant_presets do |t|
      t.string :name, null: false
      t.string :description
      t.string :option_type, null: false
      t.jsonb :values, default: [], null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end
    add_index :variant_presets, :name, unique: true
    add_index :variant_presets, :option_type
    add_index :variant_presets, :position
  end
end
