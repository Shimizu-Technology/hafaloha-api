FactoryBot.define do
  factory :order_item do
    order { nil }
    product { nil }
    product_variant { nil }
    quantity { 1 }
    unit_price_cents { 1 }
    total_price_cents { 1 }
    product_name { "MyString" }
    variant_name { "MyString" }
    product_sku { "MyString" }
  end
end
