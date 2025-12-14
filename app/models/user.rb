class User < ApplicationRecord
  # Validations
  validates :clerk_id, presence: true, uniqueness: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: %w[customer admin] }, allow_nil: false

  # Default role
  after_initialize :set_default_role, if: :new_record?

  # Associations
  has_many :cart_items, dependent: :destroy
  has_many :imports, dependent: :destroy
  # has_many :orders (future)

  # Scopes
  scope :admins, -> { where(role: 'admin') }
  scope :customers, -> { where(role: 'customer') }

  # Role helpers
  def admin?
    role == 'admin'
  end

  def customer?
    role == 'customer'
  end

  private

  def set_default_role
    self.role ||= 'customer'
  end
end
