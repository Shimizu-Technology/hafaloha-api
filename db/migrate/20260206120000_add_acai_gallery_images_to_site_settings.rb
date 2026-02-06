class AddAcaiGalleryImagesToSiteSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :site_settings, :acai_gallery_image_a_url, :string
    add_column :site_settings, :acai_gallery_image_b_url, :string
  end
end
