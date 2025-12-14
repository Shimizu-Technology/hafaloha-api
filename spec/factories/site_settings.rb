FactoryBot.define do
  factory :site_setting do
    payment_test_mode { false }
    payment_processor { "MyString" }
    store_name { "MyString" }
    store_email { "MyString" }
    store_phone { "MyString" }
    order_notification_emails { "MyText" }
    shipping_origin_address { "" }
  end
end
