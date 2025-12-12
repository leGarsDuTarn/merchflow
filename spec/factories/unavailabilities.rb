FactoryBot.define do
  factory :unavailability do
    association :user
    date { Date.tomorrow }
    notes { "CP" }
  end
end
