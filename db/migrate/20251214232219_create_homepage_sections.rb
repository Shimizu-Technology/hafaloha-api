class CreateHomepageSections < ActiveRecord::Migration[8.0]
  def change
    create_table :homepage_sections do |t|
      # Section type: hero, category_card, featured_collection, promo_banner, etc.
      t.string :section_type, null: false
      
      # Position for ordering sections
      t.integer :position, default: 0
      
      # Whether the section is visible
      t.boolean :active, default: true
      
      # Content fields (flexible JSON for different section types)
      t.string :title
      t.text :subtitle
      t.string :button_text
      t.string :button_link
      
      # Image URL (S3 or external)
      t.string :image_url
      t.string :background_image_url
      
      # Additional configuration as JSON
      # Examples:
      # - For category_card: { "collection_slug": "mens", "badge": "New" }
      # - For hero: { "overlay_opacity": 0.5, "text_alignment": "center" }
      # - For promo: { "discount_code": "SALE20", "end_date": "2025-01-01" }
      t.jsonb :settings, default: {}
      
      t.timestamps
    end

    add_index :homepage_sections, :section_type
    add_index :homepage_sections, :position
    add_index :homepage_sections, :active
  end
end
