FactoryBot.define do
  factory :product_variant do
    product { nil }
    size { "MyString" }
    color { "MyString" }
    variant_key { "MyString" }
    variant_name { "MyString" }
    sku { "MyString" }
    price_cents { 1 }
    stock_quantity { 1 }
    available { false }
    weight_oz { "9.99" }
    shopify_variant_id { "MyString" }
    barcode { "MyString" }
  end
end
