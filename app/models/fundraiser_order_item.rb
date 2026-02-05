class FundraiserOrderItem < ApplicationRecord
  belongs_to :fundraiser_order
  belongs_to :fundraiser_product_variant

  # Validations
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :price_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Callbacks
  before_validation :snapshot_product_info, on: :create

  # Money handling
  def price
    Money.new(price_cents || 0, "USD")
  end

  def total_price_cents
    (price_cents || 0) * (quantity || 1)
  end

  def total_price
    Money.new(total_price_cents, "USD")
  end

  # Delegate to variant for convenience
  delegate :sku, to: :fundraiser_product_variant, allow_nil: true

  # Get the fundraiser product through the variant
  def fundraiser_product
    fundraiser_product_variant&.fundraiser_product
  end

  private

  def snapshot_product_info
    return unless fundraiser_product_variant

    # Snapshot the product and variant names at time of order
    # This preserves the data even if product is later modified/deleted
    self.product_name ||= fundraiser_product_variant.fundraiser_product&.name
    self.variant_name ||= fundraiser_product_variant.display_name
    self.price_cents ||= fundraiser_product_variant.price_cents
  end
end
