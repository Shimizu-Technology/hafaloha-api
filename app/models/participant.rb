class Participant < ApplicationRecord
  belongs_to :fundraiser
  has_many :orders, dependent: :restrict_with_error

  # Validations
  validates :name, presence: true
  validates :participant_number, uniqueness: { scope: :fundraiser_id }, allow_nil: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_name, -> { order(:name) }
  scope :by_number, -> { order(:participant_number) }

  # Instance methods
  def display_name
    if participant_number.present?
      "##{participant_number} - #{name}"
    else
      name
    end
  end

  def total_raised_cents
    orders.paid.sum(:total_cents)
  end

  def total_raised
    Money.new(total_raised_cents, "USD")
  end
end
