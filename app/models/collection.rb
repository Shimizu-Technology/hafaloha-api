class Collection < ApplicationRecord
  # Associations
  has_many :product_collections, dependent: :destroy
  has_many :products, through: :product_collections

  # Validations
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9\-]+\z/ }

  # Scopes
  scope :published, -> { where(published: true) }
  scope :featured, -> { where(featured: true) }
  scope :by_position, -> { order(sort_order: :asc, name: :asc) }

  # Callbacks
  before_validation :generate_slug, if: -> { slug.blank? }

  # Instance methods
  def to_param
    slug
  end

  private

  def generate_slug
    self.slug = name.to_s.parameterize
  end
end
