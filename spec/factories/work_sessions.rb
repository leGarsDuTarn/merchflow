FactoryBot.define do
  factory :work_session do
    association :contract

    date { Date.today }
    start_time { Time.zone.parse("08:00") }
    end_time   { Time.zone.parse("12:00") }

    hourly_rate { 12.0 }
    break_minutes { 0 }

    shift { "morning" }
    store { "Intermarché Carmaux" }
    store_full_address { "Rue du Stade, Carmaux" }

    meal_hours_required { 5 }
    recommended { false }
  end
end
