class Order < ApplicationRecord
  belongs_to :user, optional: true  # Allow guest checkout
  belongs_to :fundraiser, optional: true
  belongs_to :participant, optional: true
  has_many :order_items, dependent: :destroy

  # Validations
  validates :order_number, presence: true, uniqueness: true
  validates :order_type, inclusion: { in: %w[retail wholesale acai] }
  validates :status, inclusion: { in: %w[pending processing shipped delivered cancelled] }
  validates :payment_status, inclusion: { in: %w[pending paid failed refunded] }
  validates :total_cents, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :retail, -> { where(order_type: 'retail') }
  scope :wholesale, -> { where(order_type: 'wholesale') }
  scope :acai, -> { where(order_type: 'acai') }
  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  scope :shipped, -> { where(status: 'shipped') }
  scope :delivered, -> { where(status: 'delivered') }
  scope :paid, -> { where(payment_status: 'paid') }
  scope :recent, -> { order(created_at: :desc) }

  # Callbacks
  before_validation :generate_order_number, if: -> { order_number.blank? }

  # Convenience aliases for customer fields
  def email
    customer_email
  end

  def email=(value)
    self.customer_email = value
  end

  def phone
    customer_phone
  end

  def phone=(value)
    self.customer_phone = value
  end

  def name
    customer_name
  end

  def name=(value)
    self.customer_name = value
  end

  # Money handling
  def subtotal
    Money.new(subtotal_cents || 0, 'USD')
  end

  def shipping_cost
    Money.new(shipping_cost_cents || 0, 'USD')
  end

  def tax
    Money.new(tax_cents || 0, 'USD')
  end

  def total
    Money.new(total_cents || 0, 'USD')
  end

  # Status helpers
  def can_cancel?
    %w[pending processing].include?(status)
  end

  def can_ship?
    status == 'processing' && payment_status == 'paid'
  end

  def is_paid?
    payment_status == 'paid'
  end

  def is_complete?
    status == 'delivered'
  end

  # Type helpers
  def retail?
    order_type == 'retail'
  end

  def wholesale?
    order_type == 'wholesale'
  end

  def acai?
    order_type == 'acai'
  end

  def requires_shipping?
    retail? || wholesale?
  end

  # Shipping address helper
  def shipping_address
    return nil unless requires_shipping?
    
    {
      line1: shipping_address_line1,
      line2: shipping_address_line2,
      city: shipping_city,
      state: shipping_state,
      zip: shipping_zip,
      country: shipping_country || 'US'
    }
  end

  def full_shipping_address
    return nil unless requires_shipping?
    
    [
      shipping_address_line1,
      shipping_address_line2,
      [shipping_city, shipping_state, shipping_zip].compact.join(', '),
      shipping_country
    ].compact.join("\n")
  end

  # Calculate totals from order items
  def calculate_totals!
    self.subtotal_cents = order_items.sum(:total_price_cents)
    self.total_cents = subtotal_cents + (shipping_cost_cents || 0) + (tax_cents || 0)
  end

  private

  def generate_order_number
    # Format: HAF-YYYYMMDD-XXXX (e.g., HAF-20251210-0001)
    date_str = Time.current.strftime('%Y%m%d')
    
    # Find the last order number for today
    last_order = Order.where('order_number LIKE ?', "HAF-#{date_str}-%").order(:order_number).last
    
    if last_order
      # Extract the sequence number and increment
      sequence = last_order.order_number.split('-').last.to_i + 1
    else
      sequence = 1
    end
    
    self.order_number = "HAF-#{date_str}-#{sequence.to_s.rjust(4, '0')}"
  end
end
