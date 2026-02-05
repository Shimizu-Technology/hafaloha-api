class ProductVariant < ApplicationRecord
  belongs_to :product

  # Validations
  validates :variant_key, presence: true
  validates :sku, presence: true, uniqueness: true
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :stock_quantity, numericality: { greater_than_or_equal_to: 0 }, if: -> { product&.inventory_level == "variant" }

  # Scopes
  scope :available, -> { where(available: true) }
  scope :in_stock, -> { where("stock_quantity > 0") }
  scope :real_variants, -> { where(is_default: false) }
  scope :default_variants, -> { where(is_default: true) }

  # Callbacks
  before_validation :generate_variant_key, if: -> { variant_key.blank? }
  before_validation :generate_variant_name, if: -> { variant_name.blank? }
  before_validation :generate_sku, if: -> { sku.blank? }

  # Money handling
  def price
    Money.new(price_cents || 0, "USD")
  end

  def price=(amount)
    self.price_cents = (amount.to_f * 100).to_i
  end

  # ==========================================
  # Options / Display Methods
  # ==========================================

  # Primary display method - uses options first, falls back to legacy columns
  def display_name
    variant_name.presence || options_display_name || legacy_display_name
  end

  # Generate display name from flexible options JSONB field
  def options_display_name
    return nil if options.blank?
    options.values.compact.join(" / ")
  end

  # Fallback to legacy size/color columns (for backward compatibility)
  def legacy_display_name
    [ size, color ].compact.join(" / ").presence
  end

  # Get options with indifferent access
  def options_hash
    return {} if options.blank?
    options.with_indifferent_access
  end

  # Get a specific option value
  def option_value(option_type)
    options_hash[option_type]
  end

  # Get all option types for this variant
  def option_types
    options_hash.keys
  end

  def in_stock?
    return true unless product.inventory_level == "variant"
    stock_quantity > 0
  end

  # Computed availability: respects both manual `available` flag AND stock levels
  def actually_available?
    return available unless product.inventory_level == "variant"
    # For variant-level tracking, must be both manually available AND in stock
    available && stock_quantity > 0
  end

  def stock_status
    return "not_tracked" unless product.inventory_level == "variant"
    return "out_of_stock" if stock_quantity <= 0
    return "low_stock" if stock_quantity <= low_stock_threshold
    "in_stock"
  end

  def low_stock?
    return false unless product.inventory_level == "variant"
    stock_quantity > 0 && stock_quantity <= low_stock_threshold
  end

  def decrement_stock!(quantity = 1)
    return unless product.inventory_level == "variant"
    update!(stock_quantity: stock_quantity - quantity)
  end

  def increment_stock!(quantity = 1)
    return unless product.inventory_level == "variant"
    update!(stock_quantity: stock_quantity + quantity)
  end

  private

  # Generate variant key from options (or legacy columns as fallback)
  def generate_variant_key
    if options.present?
      # Use options JSONB field
      parts = options.values.compact.map { |v| v.to_s.parameterize }
      self.variant_key = parts.join("-")
    else
      # Fallback to legacy columns
      parts = [ size, color ].compact.map(&:parameterize)
      self.variant_key = parts.join("-")
    end
  end

  # Generate display name from options (or legacy columns as fallback)
  def generate_variant_name
    if options.present?
      self.variant_name = options.values.compact.join(" / ")
    else
      parts = [ size, color ].compact
      self.variant_name = parts.join(" / ") if parts.any?
    end
  end

  # Generate SKU from variant key
  def generate_sku
    base = product.sku_prefix || product.slug
    self.sku = "#{base}-#{variant_key}".upcase
  end
end
