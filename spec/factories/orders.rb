FactoryBot.define do
  factory :order do
    order_number { "MyString" }
    user { nil }
    order_type { "MyString" }
    customer_name { "MyString" }
    customer_email { "MyString" }
    customer_phone { "MyString" }
    subtotal_cents { 1 }
    shipping_cost_cents { 1 }
    tax_cents { 1 }
    total_cents { 1 }
    status { "MyString" }
    payment_status { "MyString" }
    payment_intent_id { "MyString" }
    shipping_method { "MyString" }
    tracking_number { "MyString" }
  end
end
