# frozen_string_literal: true

class HomepageSection < ApplicationRecord
  include Sanitizable
  sanitize_fields :title, :subtitle, :button_text

  # Section types
  SECTION_TYPES = %w[
    hero
    category_card
    featured_products
    promo_banner
    text_block
    image_gallery
    banner
    custom
  ].freeze

  # Validations
  validates :section_type, presence: true, inclusion: { in: SECTION_TYPES }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:section_type, :position) }
  scope :by_type, ->(type) { where(section_type: type) }

  # Class methods for easy access
  class << self
    def hero
      active.by_type('hero').ordered.first
    end

    def category_cards
      active.by_type('category_card').ordered
    end

    def featured_products_section
      active.by_type('featured_products').ordered.first
    end

    def promo_banners
      active.by_type('promo_banner').ordered
    end

    # Get all active sections grouped by type
    def grouped
      active.ordered.group_by(&:section_type)
    end
  end

  # Instance methods
  def setting(key)
    settings&.dig(key.to_s)
  end

  def update_setting(key, value)
    self.settings ||= {}
    self.settings[key.to_s] = value
    save
  end
end

