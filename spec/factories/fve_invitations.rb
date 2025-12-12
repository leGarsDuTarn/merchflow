FactoryBot.define do
  factory :fve_invitation do
    email { Faker::Internet.email }
    agency { "actiale" }
    premium { false }
    used { false }
  end
end
