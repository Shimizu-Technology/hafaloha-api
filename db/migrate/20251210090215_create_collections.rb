class CreateCollections < ActiveRecord::Migration[8.1]
  def change
    create_table :collections do |t|
      t.string :name
      t.string :slug
      t.text :description
      t.string :image_url
      t.boolean :published
      t.boolean :featured
      t.integer :sort_order
      t.string :meta_title
      t.text :meta_description

      t.timestamps
    end
    add_index :collections, :slug, unique: true
  end
end
