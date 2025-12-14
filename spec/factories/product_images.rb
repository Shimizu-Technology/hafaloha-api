FactoryBot.define do
  factory :product_image do
    product { nil }
    url { "MyString" }
    alt_text { "MyString" }
    position { 1 }
    primary { false }
    shopify_image_id { "MyString" }
  end
end
