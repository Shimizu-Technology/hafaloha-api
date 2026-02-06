class AddAcaiGalleryVisibilityToSiteSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :site_settings, :acai_gallery_show_image_a, :boolean, default: true, null: false
    add_column :site_settings, :acai_gallery_show_image_b, :boolean, default: true, null: false
  end
end
