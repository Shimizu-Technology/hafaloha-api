class AddVariantsSkippedCountToImports < ActiveRecord::Migration[8.1]
  def change
    add_column :imports, :variants_skipped_count, :integer, default: 0
  end
end
