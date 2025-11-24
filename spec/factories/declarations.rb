FactoryBot.define do
  factory :declaration do
    user
    contract { association :contract, user: user }

    month { rand(1..12) }
    year  { 2024 }

    employer_name { 'Employeur Test' }

    total_minutes { rand(60..600) }
    brut_with_cp  { rand(50..300).to_f }
  end
end
