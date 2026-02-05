class FundraiserProduct < ApplicationRecord
  belongs_to :fundraiser

  has_many :fundraiser_product_variants, dependent: :destroy
  has_many :fundraiser_product_images, -> { order(position: :asc) }, dependent: :destroy
  has_many :fundraiser_order_items, through: :fundraiser_product_variants

  # Validations
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9\-]+\z/ }
  validates :base_price_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :inventory_level, inclusion: { in: %w[none product variant] }
  validates :product_stock_quantity, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true, if: -> { inventory_level == "product" }

  # Scopes
  scope :published, -> { where(published: true) }
  scope :featured, -> { where(featured: true) }
  scope :by_position, -> { order(:position) }

  # Callbacks
  before_validation :generate_slug, if: -> { slug.blank? }
  before_validation :generate_sku_prefix, if: -> { sku_prefix.blank? }
  after_save :ensure_default_variant, if: -> { saved_change_to_inventory_level? || ([ "product", "none" ].include?(inventory_level) && fundraiser_product_variants.none?) }

  # Money handling
  def base_price
    Money.new(base_price_cents || 0, "USD")
  end

  def base_price=(amount)
    self.base_price_cents = (amount.to_f * 100).to_i
  end

  # Instance methods
  def to_param
    slug
  end

  def primary_image
    fundraiser_product_images.find_by(primary: true) || fundraiser_product_images.first
  end

  def in_stock?
    case inventory_level
    when "none"
      true
    when "product"
      (product_stock_quantity || 0) > 0
    when "variant"
      fundraiser_product_variants.where("stock_quantity > 0").exists?
    else
      true
    end
  end

  def actually_available?
    return false unless published?

    case inventory_level
    when "none"
      true
    when "product"
      (product_stock_quantity || 0) > 0
    when "variant"
      fundraiser_product_variants.any?(&:actually_available?)
    else
      true
    end
  end

  def available_variants
    published? ? fundraiser_product_variants.where(available: true) : fundraiser_product_variants
  end

  def product_stock_status
    return "not_tracked" unless inventory_level == "product"
    return "out_of_stock" if (product_stock_quantity || 0) <= 0
    "in_stock"
  end

  private

  def generate_slug
    base_slug = name.to_s.parameterize
    # Ensure uniqueness by appending fundraiser_id if needed
    self.slug = "#{fundraiser_id}-#{base_slug}"
  end

  def generate_sku_prefix
    return if name.blank?
    words = name.to_s.upcase.split(/\s+/)
    if words.length > 1
      prefix = words[0][0..2] + "-" + words[1..].join("-").gsub(/[^A-Z0-9]/, "")
    else
      prefix = words[0][0..2]
    end
    # Prefix with FR (fundraiser) and fundraiser_id
    self.sku_prefix = "FR#{fundraiser_id}-#{prefix}"[0..19]
  end

  def ensure_default_variant
    return unless [ "product", "none" ].include?(inventory_level)
    return if fundraiser_product_variants.exists?(is_default: false)
    return if fundraiser_product_variants.exists?(is_default: true)

    fundraiser_product_variants.create!(
      size: "Default",
      sku: "#{sku_prefix}-DEFAULT",
      price_cents: base_price_cents,
      available: true,
      stock_quantity: 0,
      weight_oz: weight_oz,
      is_default: true
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create default fundraiser variant: #{e.message}"
  end
end
