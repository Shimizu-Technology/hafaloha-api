class FundraiserProductVariant < ApplicationRecord
  belongs_to :fundraiser_product

  has_many :fundraiser_order_items, dependent: :restrict_with_error

  # Validations
  validates :variant_key, presence: true
  validates :sku, presence: true, uniqueness: true
  validates :price_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :stock_quantity, numericality: { greater_than_or_equal_to: 0 }, if: -> { fundraiser_product&.inventory_level == "variant" }
  validates :weight_oz, numericality: { greater_than: 0 }, allow_nil: true

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

  def compare_at_price
    Money.new(compare_at_price_cents || 0, "USD")
  end

  # Display methods
  def display_name
    variant_name.presence || options_display_name || legacy_display_name || "Default"
  end

  def options_display_name
    return nil if options.blank?
    options.values.compact.join(" / ")
  end

  def legacy_display_name
    [ size, color, material ].compact.join(" / ").presence
  end

  def options_hash
    return {} if options.blank?
    options.with_indifferent_access
  end

  def option_value(option_type)
    options_hash[option_type]
  end

  # Stock helpers
  def in_stock?
    return true unless fundraiser_product&.inventory_level == "variant"
    stock_quantity > 0
  end

  def actually_available?
    return available unless fundraiser_product&.inventory_level == "variant"
    available && stock_quantity > 0
  end

  def stock_status
    return "not_tracked" unless fundraiser_product&.inventory_level == "variant"
    return "out_of_stock" if stock_quantity <= 0
    return "low_stock" if stock_quantity <= (low_stock_threshold || 5)
    "in_stock"
  end

  def low_stock?
    return false unless fundraiser_product&.inventory_level == "variant"
    stock_quantity > 0 && stock_quantity <= (low_stock_threshold || 5)
  end

  def decrement_stock!(quantity = 1)
    return unless fundraiser_product&.inventory_level == "variant"
    with_lock do
      new_qty = [ stock_quantity - quantity, 0 ].max
      update!(stock_quantity: new_qty)
    end
  end

  def increment_stock!(quantity = 1)
    return unless fundraiser_product&.inventory_level == "variant"
    with_lock do
      update!(stock_quantity: stock_quantity + quantity)
    end
  end

  private

  def generate_variant_key
    if options.present?
      parts = options.values.compact.map { |v| v.to_s.parameterize }
      self.variant_key = parts.join("-")
    else
      parts = [ size, color, material ].compact.map(&:parameterize)
      self.variant_key = parts.any? ? parts.join("-") : "default"
    end
  end

  def generate_variant_name
    if options.present?
      self.variant_name = options.values.compact.join(" / ")
    else
      parts = [ size, color, material ].compact
      self.variant_name = parts.join(" / ") if parts.any?
    end
  end

  def generate_sku
    base = fundraiser_product&.sku_prefix || "FR-PROD"
    self.sku = "#{base}-#{variant_key}".upcase
  end
end
