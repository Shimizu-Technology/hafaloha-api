class CreatePages < ActiveRecord::Migration[8.1]
  def change
    create_table :pages do |t|
      t.string :title
      t.string :slug
      t.text :content
      t.boolean :published
      t.string :meta_title
      t.text :meta_description

      t.timestamps
    end
    add_index :pages, :slug, unique: true
  end
end
