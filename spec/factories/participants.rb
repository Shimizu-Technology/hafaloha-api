FactoryBot.define do
  factory :participant do
    fundraiser { nil }
    name { "MyString" }
    participant_number { "MyString" }
    email { "MyString" }
    phone { "MyString" }
    notes { "MyText" }
    active { false }
  end
end
