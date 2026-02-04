class CreateContactSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :contact_submissions do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :subject, null: false
      t.text :message, null: false
      t.string :status, null: false, default: "new"

      t.timestamps
    end

    add_index :contact_submissions, :status
    add_index :contact_submissions, :created_at
  end
end
