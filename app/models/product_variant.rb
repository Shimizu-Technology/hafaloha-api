class ProductVariant < ApplicationRecord
  belongs_to :product

  # Validations
  validates :variant_key, presence: true
  validates :sku, presence: true, uniqueness: true
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :stock_quantity, numericality: { greater_than_or_equal_to: 0 }, if: -> { product&.inventory_level == 'variant' }

  # Scopes
  scope :available, -> { where(available: true) }
  scope :in_stock, -> { where('stock_quantity > 0') }
  scope :real_variants, -> { where(is_default: false) }
  scope :default_variants, -> { where(is_default: true) }

  # Callbacks
  before_validation :generate_variant_key, if: -> { variant_key.blank? }
  before_validation :generate_variant_name, if: -> { variant_name.blank? }
  before_validation :generate_sku, if: -> { sku.blank? }

  # Money handling
  def price
    Money.new(price_cents || 0, 'USD')
  end

  def price=(amount)
    self.price_cents = (amount.to_f * 100).to_i
  end

  # Instance methods
  def display_name
    variant_name || [size, color].compact.join(' / ')
  end

  def in_stock?
    return true unless product.inventory_level == 'variant'
    stock_quantity > 0
  end

  # Computed availability: respects both manual `available` flag AND stock levels
  def actually_available?
    return available unless product.inventory_level == 'variant'
    # For variant-level tracking, must be both manually available AND in stock
    available && stock_quantity > 0
  end

  def stock_status
    return 'not_tracked' unless product.inventory_level == 'variant'
    return 'out_of_stock' if stock_quantity <= 0
    return 'low_stock' if stock_quantity <= low_stock_threshold
    'in_stock'
  end

  def low_stock?
    return false unless product.inventory_level == 'variant'
    stock_quantity > 0 && stock_quantity <= low_stock_threshold
  end

  def decrement_stock!(quantity = 1)
    return unless product.inventory_level == 'variant'
    update!(stock_quantity: stock_quantity - quantity)
  end

  def increment_stock!(quantity = 1)
    return unless product.inventory_level == 'variant'
    update!(stock_quantity: stock_quantity + quantity)
  end

  private

  def generate_variant_key
    parts = [size, color].compact.map(&:parameterize)
    self.variant_key = parts.join('-')
  end

  def generate_variant_name
    parts = [size, color].compact
    self.variant_name = parts.join(' / ') if parts.any?
  end

  def generate_sku
    base = product.sku_prefix || product.slug
    self.sku = "#{base}-#{variant_key}".upcase
  end
end
