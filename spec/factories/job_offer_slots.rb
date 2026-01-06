FactoryBot.define do
  factory :job_offer_slot do
    job_offer { nil }
    date { "2026-01-06" }
    start_time { "2026-01-06 10:44:15" }
    end_time { "2026-01-06 10:44:15" }
    break_start_time { "2026-01-06 10:44:15" }
    break_end_time { "2026-01-06 10:44:15" }
  end
end
