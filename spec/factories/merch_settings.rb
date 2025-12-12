FactoryBot.define do
  factory :merch_setting do
    association :merch, factory: :user

    # Valeurs par défaut sécurisées
    allow_identity { false }
    share_address { false }
    role_merch { true }
    role_anim { false }
    preferred_contact_channel { "phone" }
  end
end
