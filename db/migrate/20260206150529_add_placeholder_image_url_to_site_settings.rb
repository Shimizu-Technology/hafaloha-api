class AddPlaceholderImageUrlToSiteSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :site_settings, :placeholder_image_url, :string
  end
end
