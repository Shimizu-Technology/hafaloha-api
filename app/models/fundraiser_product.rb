class FundraiserProduct < ApplicationRecord
  belongs_to :fundraiser
  belongs_to :product

  # Validations
  validates :price_cents, presence: true, numericality: { greater_than: 0 }
  validates :product_id, uniqueness: { scope: :fundraiser_id, message: 'already added to this fundraiser' }
  validates :min_quantity, numericality: { greater_than_or_equal_to: 1 }, allow_nil: true
  validates :max_quantity, numericality: { greater_than: 0 }, allow_nil: true
  validate :max_quantity_greater_than_min

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_position, -> { order(:position) }

  # Delegations for easy access
  delegate :name, :description, :primary_image, :product_variants, :slug, to: :product

  # Money handling
  def price
    Money.new(price_cents, 'USD')
  end

  # Display name for admin
  def display_name
    product.name
  end

  # Get available variants for this product
  def available_variants
    product.product_variants.where(available: true)
  end

  # Check if product is available for ordering
  def available?
    active? && product.published? && fundraiser.active?
  end

  private

  def max_quantity_greater_than_min
    return unless max_quantity.present? && min_quantity.present?
    
    if max_quantity < min_quantity
      errors.add(:max_quantity, 'must be greater than or equal to minimum quantity')
    end
  end
end
