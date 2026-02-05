class Fundraiser < ApplicationRecord
  has_many :participants, dependent: :destroy
  has_many :orders, dependent: :restrict_with_error
  has_many :fundraiser_products, dependent: :destroy
  has_many :products, through: :fundraiser_products

  # Validations
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9\-]+\z/ }
  validates :status, inclusion: { in: %w[draft active ended cancelled] }, allow_nil: false

  # Scopes
  scope :active, -> { where(status: "active").where("start_date <= ? AND (end_date >= ? OR end_date IS NULL)", Date.current, Date.current) }
  scope :published, -> { where(status: %w[active ended]) }
  scope :upcoming, -> { where("start_date > ?", Date.current) }
  scope :ended, -> { where("end_date < ?", Date.current).or(where(status: "ended")) }
  scope :recent, -> { order(start_date: :desc) }
  scope :by_status, ->(status) { where(status: status) if status.present? }

  # Callbacks
  before_validation :generate_slug, if: -> { slug.blank? }

  # Money handling
  def goal_amount
    Money.new(goal_amount_cents || 0, "USD")
  end

  def raised_amount
    Money.new(raised_amount_cents || 0, "USD")
  end

  # Status helpers
  def active?
    status == "active" && current?
  end

  def current?
    return false unless start_date && end_date
    Date.current.between?(start_date, end_date)
  end

  def upcoming?
    start_date && start_date > Date.current
  end

  def ended?
    status == "ended" || (end_date && end_date < Date.current)
  end

  def progress_percentage
    return 0 if goal_amount_cents.nil? || goal_amount_cents.zero?
    ((raised_amount_cents.to_f / goal_amount_cents) * 100).round(2)
  end

  # Instance methods
  def to_param
    slug
  end

  def update_raised_amount!
    total = orders.paid.sum(:total_cents)
    update!(raised_amount_cents: total)
  end

  private

  def generate_slug
    self.slug = name.to_s.parameterize
  end
end
