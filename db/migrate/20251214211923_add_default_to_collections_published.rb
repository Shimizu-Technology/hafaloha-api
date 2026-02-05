class AddDefaultToCollectionsPublished < ActiveRecord::Migration[8.1]
  def change
    # Set default to false for published column
    change_column_default :collections, :published, from: nil, to: false

    # Update existing NULL values to false
    reversible do |dir|
      dir.up do
        execute "UPDATE collections SET published = false WHERE published IS NULL"
      end
    end
  end
end
