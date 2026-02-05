class FundraiserProductImage < ApplicationRecord
  belongs_to :fundraiser_product

  # Validations
  validates :s3_key, presence: true

  # Scopes
  scope :by_position, -> { order(:position) }
  scope :primary_first, -> { order(primary: :desc, position: :asc) }

  # Instance methods
  def url
    return nil if s3_key.blank?

    # Construct S3 URL from key
    bucket = ENV.fetch("AWS_S3_BUCKET", "hafaloha-assets")
    region = ENV.fetch("AWS_REGION", "us-west-2")

    if ENV["CLOUDFRONT_DOMAIN"].present?
      "https://#{ENV['CLOUDFRONT_DOMAIN']}/#{s3_key}"
    else
      "https://#{bucket}.s3.#{region}.amazonaws.com/#{s3_key}"
    end
  end

  # Set this image as primary and unset others
  def set_as_primary!
    FundraiserProductImage.transaction do
      fundraiser_product.fundraiser_product_images.where.not(id: id).update_all(primary: false)
      update!(primary: true)
    end
  end
end
