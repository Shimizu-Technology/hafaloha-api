FactoryBot.define do
  factory :product do
    name { "MyString" }
    slug { "MyString" }
    description { "MyText" }
    base_price_cents { 1 }
    sku_prefix { "MyString" }
    track_inventory { false }
    weight_oz { "9.99" }
    published { false }
    featured { false }
    product_type { "MyString" }
    shopify_product_id { "MyString" }
    vendor { "MyString" }
    meta_title { "MyString" }
    meta_description { "MyText" }
  end
end
