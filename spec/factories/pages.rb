FactoryBot.define do
  factory :page do
    title { "MyString" }
    slug { "MyString" }
    content { "MyText" }
    published { false }
    meta_title { "MyString" }
    meta_description { "MyText" }
  end
end
