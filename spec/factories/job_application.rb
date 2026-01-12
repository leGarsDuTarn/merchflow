FactoryBot.define do
  factory :job_application do
    association :job_offer
    association :merch, factory: :user, role: :merch
    message { "Bonjour, je suis disponible et motivé pour cette mission." }
    status { "pending" }

    # Pas besoin de remplir les snapshots, les callback before_create s'en occupe.
  end
end
