class CreateFundraisers < ActiveRecord::Migration[8.1]
  def change
    create_table :fundraisers do |t|
      t.string :name
      t.string :slug
      t.text :description
      t.string :contact_name
      t.string :contact_email
      t.string :contact_phone
      t.date :start_date
      t.date :end_date
      t.string :status
      t.integer :goal_amount_cents
      t.integer :raised_amount_cents
      t.string :image_url

      t.timestamps
    end
    add_index :fundraisers, :slug, unique: true
  end
end
