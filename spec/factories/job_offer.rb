FactoryBot.define do
  factory :job_offer do
    association :fve, factory: :user, role: :fve
    title { "Mission Merchandising Carrefour" }
    description { "Mise en rayon des produits frais et balisage des prix pour la nouvelle gamme." }
    mission_type { "merchandising" }
    contract_type { "CDD" }
    company_name { "Coca-Cola" }
    store_name { "Carrefour Market" }
    address { "12 rue de la Paix" }
    zipcode { "75001" }
    city { "Paris" }
    contact_email { "recrutement@agence.fr" }
    contact_phone { "0612345678" }
    start_date { Date.tomorrow }
    end_date { Date.tomorrow }
    hourly_rate { 13.50 } # Supérieur au 12.02 requis
    headcount_required { 1 }
    status { "published" }

    # Trait pour créer l'offre avec déjà un créneau (slot)
    trait :with_slots do
      after(:create) do |job_offer|
        create(:job_offer_slot, job_offer: job_offer)
      end
    end
  end
end
