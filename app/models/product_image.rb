class ProductImage < ApplicationRecord
  belongs_to :product

  # Validations
  validates :s3_key, presence: true
  # Keep URL for backwards compatibility with old records, but it's optional now
  validates :url, presence: true, if: -> { s3_key.blank? }

  # Scopes
  scope :by_position, -> { order(position: :asc) }
  scope :primary_first, -> { order(primary: :desc, position: :asc) }

  # Callbacks
  after_create :set_as_primary_if_first
  after_destroy :reassign_primary_if_needed

  # Generate a fresh signed URL from the S3 key
  # This URL will be valid for 1 hour (3600 seconds)
  def signed_url
    return url if s3_key.blank? # Fallback for old records with direct URLs

    blob = ActiveStorage::Blob.find_by(key: s3_key)
    return url if blob.nil? # Fallback if blob not found

    blob.url(expires_in: 1.hour)
  end

  private

  def set_as_primary_if_first
    return if product.product_images.where.not(id: id).exists?
    update_column(:primary, true)
  end

  def reassign_primary_if_needed
    return unless primary
    next_image = product.product_images.order(position: :asc).first
    next_image&.update_column(:primary, true)
  end
end
