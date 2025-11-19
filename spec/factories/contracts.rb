FactoryBot.define do
  factory :contract do
    association :user

    name { "Contrat Test" }
    agency { "actiale" }
    contract_type { "cdd" }

    start_date { Date.today }
    end_date   { nil }

    night_rate { 0.5 }
    ifm_rate   { 0.1 }
    cp_rate    { 0.1 }

    km_rate  { 0.29 }
    km_limit { 40 }
    km_unlimited { false }

    annex_minutes_per_hour { 0 }
    annex_threshold_hours  { 0 }
    annex_extra_minutes    { 0 }
  end
end
