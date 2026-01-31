class Order < ApplicationRecord
  belongs_to :user, optional: true  # Allow guest checkout
  belongs_to :fundraiser, optional: true
  belongs_to :participant, optional: true
  has_many :order_items, dependent: :destroy
  has_many :refunds, dependent: :destroy

  # Valid statuses by order type:
  # Retail:    pending → processing → shipped → delivered (or cancelled)
  # Acai:      pending → confirmed → ready → picked_up (or cancelled)
  # Wholesale: pending → confirmed → ready → picked_up (or cancelled)
  VALID_STATUSES = %w[pending confirmed processing ready shipped picked_up delivered cancelled].freeze
  RETAIL_STATUSES = %w[pending processing shipped delivered cancelled].freeze
  PICKUP_STATUSES = %w[pending confirmed ready picked_up cancelled].freeze

  # Validations
  validates :order_number, presence: true, uniqueness: true
  validates :order_type, inclusion: { in: %w[retail wholesale acai] }
  validates :status, inclusion: { in: VALID_STATUSES }
  validates :payment_status, inclusion: { in: %w[pending paid failed refunded] }
  validates :total_cents, numericality: { greater_than_or_equal_to: 0 }

  # Guest orders (no user_id) must have contact email so we can reach the customer
  validates :customer_email, presence: { message: "is required for guest checkout" }, if: -> { user_id.nil? }

  # Scopes
  scope :retail, -> { where(order_type: 'retail') }
  scope :wholesale, -> { where(order_type: 'wholesale') }
  scope :acai, -> { where(order_type: 'acai') }
  scope :pending, -> { where(status: 'pending') }
  scope :confirmed, -> { where(status: 'confirmed') }
  scope :processing, -> { where(status: 'processing') }
  scope :ready, -> { where(status: 'ready') }
  scope :shipped, -> { where(status: 'shipped') }
  scope :picked_up, -> { where(status: 'picked_up') }
  scope :delivered, -> { where(status: 'delivered') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :paid, -> { where(payment_status: 'paid') }
  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where.not(status: 'cancelled') }

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
  # Refund helpers
  def total_refunded_cents
    refunds.succeeded.sum(:amount_cents)
  end

  def fully_refunded?
    total_refunded_cents >= total_cents
  end

  def refundable_amount_cents
    total_cents - total_refunded_cents
  end

  def can_refund?
    payment_status == 'paid' && refundable_amount_cents > 0
  end

    def can_cancel?
    %w[pending confirmed processing ready].include?(status)
  end

  def can_ship?
    status == 'processing' && payment_status == 'paid'
  end

  def can_mark_ready?
    (acai? || wholesale?) && status == 'confirmed' && payment_status == 'paid'
  end

  def is_paid?
    payment_status == 'paid'
  end

  def is_complete?
    status.in?(%w[delivered picked_up])
  end
  
  def is_pickup_order?
    acai? || wholesale?
  end
  
  # Get valid next statuses based on order type and current status
  def next_status_options
    if retail?
      case status
      when 'pending' then ['processing', 'cancelled']
      when 'processing' then ['shipped', 'cancelled']
      when 'shipped' then ['delivered']
      else []
      end
    else
      case status
      when 'pending' then ['confirmed', 'cancelled']
      when 'confirmed' then ['ready', 'cancelled']
      when 'ready' then ['picked_up']
      else []
      end
    end
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
    # Format: HAF-{TYPE}-YYYYMMDD-XXXX
    # - Retail:    HAF-R-20251210-0001
    # - Acai:      HAF-A-20251210-0001
    # - Wholesale: HAF-W-20251210-0001
    type_prefix = case order_type
                  when 'acai' then 'A'
                  when 'wholesale' then 'W'
                  else 'R' # retail is default
                  end
    
    date_str = Time.current.strftime('%Y%m%d')
    prefix = "HAF-#{type_prefix}-#{date_str}"
    
    # Find the last order number with this prefix for today
    last_order = Order.where('order_number LIKE ?', "#{prefix}-%").order(:order_number).last
    
    if last_order
      # Extract the sequence number and increment
      sequence = last_order.order_number.split('-').last.to_i + 1
    else
      sequence = 1
    end
    
    self.order_number = "#{prefix}-#{sequence.to_s.rjust(4, '0')}"
  end
end
