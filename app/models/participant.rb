class Participant < ApplicationRecord
  belongs_to :fundraiser

  has_many :fundraiser_orders, dependent: :restrict_with_error
  # Legacy association
  has_many :orders, dependent: :restrict_with_error

  # Validations
  validates :name, presence: true
  validates :unique_code, presence: true, uniqueness: true
  validates :participant_number, uniqueness: { scope: :fundraiser_id }, allow_nil: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :goal_amount_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_name, -> { order(:name) }
  scope :by_number, -> { order(:participant_number) }
  scope :by_code, -> { order(:unique_code) }

  # Callbacks
  before_validation :generate_unique_code, if: -> { unique_code.blank? }

  # Money handling
  def goal_amount
    Money.new(goal_amount_cents || 0, "USD")
  end

  def goal_amount=(amount)
    self.goal_amount_cents = (amount.to_f * 100).to_i
  end

  # Instance methods
  def display_name
    if participant_number.present?
      "##{participant_number} - #{name}"
    else
      name
    end
  end

  def total_raised_cents
    fundraiser_orders.where(payment_status: "paid").sum(:total_cents)
  end

  def total_raised
    Money.new(total_raised_cents, "USD")
  end

  def progress_percentage
    return 0 if goal_amount_cents.nil? || goal_amount_cents.zero?
    ((total_raised_cents.to_f / goal_amount_cents) * 100).round(2)
  end

  def order_count
    fundraiser_orders.where(payment_status: "paid").count
  end

  def stats
    {
      total_raised_cents: total_raised_cents,
      goal_amount_cents: goal_amount_cents,
      progress_percentage: progress_percentage,
      order_count: order_count
    }
  end

  # URL for sharing
  def share_url
    # Returns the unique code for use in URLs
    # Frontend will construct the full URL
    unique_code
  end

  private

  def generate_unique_code
    loop do
      # Generate a readable code: XXXX-XXXX format
      # Uses alphanumerics, avoiding confusing chars (0, O, 1, I, L)
      chars = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
      code = Array.new(8) { chars[SecureRandom.random_number(chars.length)] }
      code.insert(4, "-")
      self.unique_code = code.join

      break unless Participant.exists?(unique_code: unique_code)
    end
  end
end
