FactoryBot.define do
  factory :contract do
    association :user

    name { 'Contrat Test' }

    agency { :actiale }
    contract_type { :cdd }

    night_rate { 0.5 }
    ifm_rate   { 0.1 }
    cp_rate    { 0.1 }

    km_rate  { 0.29 }
    km_limit { 40 }
    km_unlimited { false }
  end
end
