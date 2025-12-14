class CreateParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :participants do |t|
      t.references :fundraiser, null: false, foreign_key: true
      t.string :name
      t.string :participant_number
      t.string :email
      t.string :phone
      t.text :notes
      t.boolean :active

      t.timestamps
    end
  end
end
