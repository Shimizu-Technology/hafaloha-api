# frozen_string_literal: true

class AcaiPlacardOption < ApplicationRecord
  # Validations
  validates :name, presence: true
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :position, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :available, -> { where(available: true) }
  scope :ordered, -> { order(position: :asc, name: :asc) }

  # Instance methods
  def price
    Money.new(price_cents, 'USD')
  end

  def price=(amount)
    self.price_cents = (amount.to_f * 100).to_i
  end

  def formatted_price
    price_cents > 0 ? "+$#{'%.2f' % (price_cents / 100.0)}" : "Included"
  end

  # Class methods
  def self.for_display
    available.ordered
  end
end
