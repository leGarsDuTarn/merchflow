FactoryBot.define do
  factory :job_offer_slot do
    association :job_offer
    date { Date.tomorrow }
    start_time { Time.zone.parse("08:00") }
    end_time { Time.zone.parse("17:00") }
    break_start_time { Time.zone.parse("12:00") }
    break_end_time { Time.zone.parse("13:00") }
  end
end
