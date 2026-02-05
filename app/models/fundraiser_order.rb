class FundraiserOrder < ApplicationRecord
  belongs_to :fundraiser
  belongs_to :participant, optional: true

  has_many :fundraiser_order_items, dependent: :destroy

  # Valid statuses
  VALID_STATUSES = %w[pending paid processing shipped delivered cancelled].freeze
  VALID_PAYMENT_STATUSES = %w[pending paid failed refunded].freeze

  # Validations
  validates :order_number, presence: true, uniqueness: true
  validates :status, inclusion: { in: VALID_STATUSES }
  validates :payment_status, inclusion: { in: VALID_PAYMENT_STATUSES }
  validates :total_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :customer_email, presence: true
  validates :customer_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  # Scopes
  scope :pending, -> { where(status: "pending") }
  scope :paid, -> { where(payment_status: "paid") }
  scope :processing, -> { where(status: "processing") }
  scope :shipped, -> { where(status: "shipped") }
  scope :delivered, -> { where(status: "delivered") }
  scope :cancelled, -> { where(status: "cancelled") }
  scope :active, -> { where.not(status: "cancelled") }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_participant, ->(participant_id) { where(participant_id: participant_id) }

  # Callbacks
  before_validation :generate_order_number, if: -> { order_number.blank? }
  after_update :restore_inventory_for_cancellation, if: -> { saved_change_to_status? && status == "cancelled" }
  after_update :update_fundraiser_raised_amount, if: -> { saved_change_to_payment_status? }

  # Money handling
  def subtotal
    Money.new(subtotal_cents || 0, "USD")
  end

  def shipping
    Money.new(shipping_cents || 0, "USD")
  end

  def tax
    Money.new(tax_cents || 0, "USD")
  end

  def total
    Money.new(total_cents || 0, "USD")
  end

  # Convenience aliases
  def email
    customer_email
  end

  def email=(value)
    self.customer_email = value
  end

  def phone
    customer_phone
  end

  def name
    customer_name
  end

  # Status helpers
  def can_cancel?
    %w[pending paid processing].include?(status)
  end

  def can_ship?
    status == "processing" && payment_status == "paid"
  end

  def is_paid?
    payment_status == "paid"
  end

  def is_complete?
    status == "delivered"
  end

  # Get valid next statuses
  def next_status_options
    case status
    when "pending" then [ "processing", "cancelled" ]
    when "paid" then [ "processing", "cancelled" ]
    when "processing" then [ "shipped", "cancelled" ]
    when "shipped" then [ "delivered" ]
    else []
    end
  end

  # Shipping address helpers
  def shipping_address
    {
      line1: shipping_address_line1,
      line2: shipping_address_line2,
      city: shipping_city,
      state: shipping_state,
      zip: shipping_zip,
      country: shipping_country || "US"
    }
  end

  def full_shipping_address
    [
      shipping_address_line1,
      shipping_address_line2,
      [ shipping_city, shipping_state, shipping_zip ].compact.join(", "),
      shipping_country
    ].compact.reject(&:blank?).join("\n")
  end

  def has_shipping_address?
    shipping_address_line1.present? && shipping_city.present? && shipping_state.present? && shipping_zip.present?
  end

  # Calculate totals from order items
  def calculate_totals!
    self.subtotal_cents = fundraiser_order_items.sum { |item| item.price_cents * item.quantity }
    self.total_cents = subtotal_cents + (shipping_cents || 0) + (tax_cents || 0)
  end

  def recalculate_totals!
    calculate_totals!
    save!
  end

  # Restore inventory when order is cancelled
  def restore_inventory_for_cancellation
    fundraiser_order_items.includes(fundraiser_product_variant: :fundraiser_product).each do |item|
      variant = item.fundraiser_product_variant
      next unless variant

      product = variant.fundraiser_product
      next unless product

      case product.inventory_level
      when "variant"
        variant.increment_stock!(item.quantity)
      when "product"
        product.with_lock do
          new_qty = (product.product_stock_quantity || 0) + item.quantity
          product.update!(product_stock_quantity: new_qty)
        end
      end
    end

    Rails.logger.info "Inventory restored for cancelled fundraiser order ##{order_number}"
  end

  private

  def generate_order_number
    date_str = Time.current.strftime("%Y%m%d")
    prefix = "FR-#{fundraiser_id}-#{date_str}"

    last_order = FundraiserOrder.where("order_number LIKE ?", "#{prefix}-%").order(:order_number).last

    sequence = if last_order
                 last_order.order_number.split("-").last.to_i + 1
    else
                 1
    end

    self.order_number = "#{prefix}-#{sequence.to_s.rjust(4, '0')}"
  end

  def update_fundraiser_raised_amount
    fundraiser&.update_raised_amount!
  end
end
