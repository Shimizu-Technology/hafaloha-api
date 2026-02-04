class AddProgressFieldsToImports < ActiveRecord::Migration[8.1]
  def change
    add_column :imports, :total_products, :integer, default: 0
    add_column :imports, :processed_products, :integer, default: 0
    add_column :imports, :progress_percent, :integer, default: 0
    add_column :imports, :current_step, :string
    add_column :imports, :last_progress_at, :datetime
  end
end
