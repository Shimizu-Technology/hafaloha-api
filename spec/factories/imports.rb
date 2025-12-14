FactoryBot.define do
  factory :import do
    user { nil }
    status { "MyString" }
    filename { "MyString" }
    products_count { 1 }
    variants_count { 1 }
    images_count { 1 }
    collections_count { 1 }
    error_messages { "MyText" }
    started_at { "2025-12-14 11:42:13" }
    completed_at { "2025-12-14 11:42:13" }
  end
end
