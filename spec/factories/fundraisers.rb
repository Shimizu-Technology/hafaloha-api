FactoryBot.define do
  factory :fundraiser do
    name { "MyString" }
    slug { "MyString" }
    description { "MyText" }
    contact_name { "MyString" }
    contact_email { "MyString" }
    contact_phone { "MyString" }
    start_date { "2025-12-10" }
    end_date { "2025-12-10" }
    status { "MyString" }
    goal_amount_cents { 1 }
    raised_amount_cents { 1 }
    image_url { "MyString" }
  end
end
