class AddAcaiGalleryTextToSiteSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :site_settings, :acai_gallery_heading, :string
    add_column :site_settings, :acai_gallery_subtext, :string
  end
end
