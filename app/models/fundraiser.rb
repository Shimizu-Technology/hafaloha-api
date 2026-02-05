class Fundraiser < ApplicationRecord
  # Associations
  has_many :participants, dependent: :destroy
  has_many :fundraiser_products, dependent: :destroy
  has_many :fundraiser_orders, dependent: :restrict_with_error

  # Legacy association (for backward compatibility with any existing Order references)
  has_many :orders, dependent: :restrict_with_error

  # Validations
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9\-]+\z/ }
  validates :organization_name, presence: true
  validates :status, inclusion: { in: %w[draft active completed cancelled] }, allow_nil: false
  validates :payout_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true

  # Scopes
  scope :draft, -> { where(status: "draft") }
  scope :active, -> { where(status: "active").where("start_date <= ? AND (end_date >= ? OR end_date IS NULL)", Date.current, Date.current) }
  scope :published, -> { where(published: true) }
  scope :completed, -> { where(status: "completed") }
  scope :upcoming, -> { where("start_date > ?", Date.current) }
  scope :ended, -> { where("end_date < ?", Date.current).or(where(status: "completed")) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) if status.present? }

  # Callbacks
  before_validation :generate_slug, if: -> { slug.blank? }

  # Money handling
  def goal_amount
    Money.new(goal_amount_cents || 0, "USD")
  end

  def goal_amount=(amount)
    self.goal_amount_cents = (amount.to_f * 100).to_i
  end

  def raised_amount
    Money.new(raised_amount_cents, "USD")
  end

  # Calculate raised amount from paid fundraiser orders
  def calculate_raised_amount_cents
    fundraiser_orders.where(payment_status: "paid").sum(:total_cents)
  end

  def update_raised_amount!
    update!(raised_amount_cents: calculate_raised_amount_cents)
  end

  # Status helpers
  def active?
    status == "active" && current?
  end

  def current?
    return true unless start_date # If no start date, consider it current
    return false if start_date > Date.current # Not started yet

    # If no end date, it's current; otherwise check if before end date
    end_date.nil? || end_date >= Date.current
  end

  def upcoming?
    start_date && start_date > Date.current
  end

  def ended?
    status == "completed" || (end_date && end_date < Date.current)
  end

  def progress_percentage
    return 0 if goal_amount_cents.nil? || goal_amount_cents.zero?
    ((raised_amount_cents.to_f / goal_amount_cents) * 100).round(2)
  end

  # Payout calculations
  def organization_payout_cents
    return 0 unless payout_percentage&.positive?
    ((raised_amount_cents || 0) * (payout_percentage / 100.0)).round
  end

  def organization_payout
    Money.new(organization_payout_cents, "USD")
  end

  # Stats
  def stats
    {
      total_raised_cents: raised_amount_cents || 0,
      goal_amount_cents: goal_amount_cents,
      progress_percentage: progress_percentage,
      organization_payout_cents: organization_payout_cents,
      participant_count: participants.count,
      active_participant_count: participants.active.count,
      product_count: fundraiser_products.count,
      published_product_count: fundraiser_products.published.count,
      order_count: fundraiser_orders.count,
      paid_order_count: fundraiser_orders.where(payment_status: "paid").count
    }
  end

  # Instance methods
  def to_param
    slug
  end

  private

  def generate_slug
    self.slug = name.to_s.parameterize
  end
end
