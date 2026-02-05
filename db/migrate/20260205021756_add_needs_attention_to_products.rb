class AddNeedsAttentionToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :needs_attention, :boolean, default: false, null: false
    add_column :products, :import_notes, :text
  end
end
