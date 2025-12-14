class AddS3KeyToProductImages < ActiveRecord::Migration[8.1]
  def change
    add_column :product_images, :s3_key, :string
  end
end
