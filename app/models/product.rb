class Product < ApplicationRecord
  # Associations
  has_many :product_variants, dependent: :destroy
  has_many :product_images, -> { order(position: :asc) }, dependent: :destroy
  has_many :product_collections, dependent: :destroy
  has_many :collections, through: :product_collections
  has_many :order_items, dependent: :restrict_with_error
  has_many :fundraiser_products, dependent: :destroy
  has_many :fundraisers, through: :fundraiser_products

  # Validations
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9\-]+\z/ }
  validates :base_price_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :inventory_level, inclusion: { in: %w[none product variant] }
  validates :product_stock_quantity, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true, if: -> { inventory_level == 'product' }
  validates :product_low_stock_threshold, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Scopes
  scope :published, -> { where(published: true) }
  scope :featured, -> { where(featured: true) }
  scope :active, -> { where(archived: false) }
  scope :archived, -> { where(archived: true) }
  scope :by_type, ->(type) { where(product_type: type) }
  scope :in_stock, -> { 
    where(inventory_level: 'none')
      .or(where(inventory_level: 'product').where('product_stock_quantity > 0'))
      .or(where(inventory_level: 'variant').joins(:product_variants).where('product_variants.stock_quantity > 0'))
  }

  # Callbacks
  before_validation :generate_slug, if: -> { slug.blank? }
  before_validation :generate_sku_prefix, if: -> { sku_prefix.blank? }
  after_save :ensure_default_variant, if: -> { saved_change_to_inventory_level? || (['product', 'none'].include?(inventory_level) && product_variants.none?) }
  after_update :handle_inventory_level_change, if: -> { saved_change_to_inventory_level? }

  # Money handling
  def base_price
    Money.new(base_price_cents || 0, 'USD')
  end

  def base_price=(amount)
    self.base_price_cents = (amount.to_f * 100).to_i
  end

  # Instance methods
  def to_param
    slug
  end

  def primary_image
    product_images.find_by(primary: true) || product_images.first
  end

  def in_stock?
    case inventory_level
    when 'none'
      true
    when 'product'
      (product_stock_quantity || 0) > 0
    when 'variant'
      product_variants.where('stock_quantity > 0').exists?
    else
      true
    end
  end

  # Computed availability: respects both `published` status AND stock levels
  def actually_available?
    return false unless published?
    return false if archived? # Archived products are never available
    
    case inventory_level
    when 'none'
      true  # Always available if published and not tracking inventory
    when 'product'
      (product_stock_quantity || 0) > 0  # Must have product-level stock
    when 'variant'
      # Must have at least one variant that's actually available
      product_variants.any? { |v| v.actually_available? }
    else
      true
    end
  end
  
  # Archive/Unarchive methods
  def archive!
    update!(archived: true, published: false)
  end
  
  def unarchive!
    update!(archived: false)
  end
  
  def archived?
    archived == true
  end

  def product_stock_status
    return 'not_tracked' unless inventory_level == 'product'
    return 'out_of_stock' if (product_stock_quantity || 0) <= 0
    return 'low_stock' if (product_stock_quantity || 0) <= (product_low_stock_threshold || 5)
    'in_stock'
  end

  def product_low_stock?
    return false unless inventory_level == 'product'
    qty = product_stock_quantity || 0
    threshold = product_low_stock_threshold || 5
    qty > 0 && qty <= threshold
  end

  def available_variants
    published? ? product_variants.where(available: true) : product_variants
  end

  private

  def generate_slug
    self.slug = name.to_s.parameterize
  end
  
  def generate_sku_prefix
    # Generate SKU prefix from product name
    # Example: "Hafaloha T-Shirt" -> "HAF-TSHIRT"
    words = name.to_s.upcase.split(/\s+/)
    if words.length > 1
      # Take first 3 letters of first word + first word of second part
      prefix = words[0][0..2] + '-' + words[1..].join('-').gsub(/[^A-Z0-9]/, '')
    else
      # Just use first 3 letters
      prefix = words[0][0..2]
    end
    self.sku_prefix = prefix[0..19] # Limit length
  end
  
  # Auto-create default variant for product-level inventory AND no-tracking
  def ensure_default_variant
    # Only create default variant for 'product' or 'none' inventory levels
    return unless ['product', 'none'].include?(inventory_level)
    return if product_variants.exists?(is_default: false) # Has real variants
    return if product_variants.exists?(is_default: true) # Already has default
    
    Rails.logger.info "🔧 Auto-creating default variant for #{inventory_level} inventory: #{name}"
    
    product_variants.create!(
      size: 'Default',
      sku: "#{sku_prefix}-DEFAULT",
      price_cents: base_price_cents,
      available: true,
      stock_quantity: 0, # Not used for product-level or none
      weight_oz: weight_oz,
      is_default: true
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "❌ Failed to create default variant: #{e.message}"
    # Don't fail the product save if variant creation fails
  end
  
  # Handle inventory level changes
  def handle_inventory_level_change
    old_level, new_level = saved_change_to_inventory_level
    
    case [old_level, new_level]
    when ['product', 'variant'], ['none', 'variant']
      # Scenario 1: Product-level/None → Variant-level
      # Delete auto-created default variants (Option A)
      deleted_count = product_variants.where(is_default: true).destroy_all.count
      Rails.logger.info "🗑️  Deleted #{deleted_count} default variant(s) when switching to variant-level for: #{name}"
      
    when ['variant', 'product'], ['variant', 'none']
      # Scenario 2: Variant-level → Product-level/None
      # Sum variant stock and set product stock (Option C)
      total_stock = product_variants.where(is_default: false).sum(:stock_quantity)
      update_column(:product_stock_quantity, total_stock) if new_level == 'product'
      Rails.logger.info "📦 Summed variant stock (#{total_stock}) when switching to #{new_level} for: #{name}"
      
      # Delete all variants (real + default) when switching away from variant-level
      deleted_count = product_variants.destroy_all.count
      Rails.logger.info "🗑️  Deleted #{deleted_count} variant(s) when switching to #{new_level} for: #{name}"
      
      # Ensure default variant is created for product/none
      ensure_default_variant
      
    when [nil, 'product'], ['none', 'product'], ['product', 'none']
      # Switching between product and none, or new product
      ensure_default_variant
    end
  end
end
