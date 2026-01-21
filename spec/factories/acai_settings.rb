FactoryBot.define do
  factory :acai_setting do
    base_price_cents { 1 }
    name { "MyString" }
    description { "MyText" }
    pickup_location { "MyString" }
    pickup_instructions { "MyText" }
    advance_hours { 1 }
    max_per_slot { 1 }
    active { false }
  end
end
