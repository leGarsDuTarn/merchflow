FactoryBot.define do
  factory :kilometer_log do
    distance { 5.0 }
    association :work_session
  end
end
