class ProductCollection < ApplicationRecord
  belongs_to :product
  belongs_to :collection

  validates :product_id, uniqueness: { scope: :collection_id }
end
