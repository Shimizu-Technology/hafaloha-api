FactoryBot.define do
  factory :acai_blocked_slot do
    blocked_date { "2025-12-10" }
    start_time { "2025-12-10 19:04:55" }
    end_time { "2025-12-10 19:04:55" }
    reason { "MyString" }
  end
end
