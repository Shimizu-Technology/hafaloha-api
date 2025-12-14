FactoryBot.define do
  factory :collection do
    name { "MyString" }
    slug { "MyString" }
    description { "MyText" }
    image_url { "MyString" }
    published { false }
    featured { false }
    sort_order { 1 }
    meta_title { "MyString" }
    meta_description { "MyText" }
  end
end
