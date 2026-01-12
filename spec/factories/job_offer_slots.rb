FactoryBot.define do
  factory :job_offer_slot do
    association :job_offer
    date { Date.tomorrow }
    start_time { date.to_time.change(hour: 8, min: 0) }
    end_time   { date.to_time.change(hour: 17, min: 0) }
    break_start_time { date.to_time.change(hour: 12, min: 0) }
    break_end_time   { date.to_time.change(hour: 13, min: 0) }
  end
end
