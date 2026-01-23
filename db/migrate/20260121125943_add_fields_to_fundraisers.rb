class AddFieldsToFundraisers < ActiveRecord::Migration[8.1]
  def change
    add_column :fundraisers, :pickup_location, :string
    add_column :fundraisers, :pickup_instructions, :text
    add_column :fundraisers, :allow_shipping, :boolean, default: false, null: false
    add_column :fundraisers, :shipping_note, :text
    add_column :fundraisers, :public_message, :text  # Message shown on public page
    add_column :fundraisers, :thank_you_message, :text  # Shown after order
  end
end
