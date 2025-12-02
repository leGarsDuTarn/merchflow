# app/models/merch_setting.rb
class MerchSetting < ApplicationRecord
  # ============================================================
  # RELATIONS
  # ============================================================
  # Un MerchSetting appartient à un User (nommé 'merch')
  # On spécifie 'user_id' car le nom de l'association est 'merch'
  belongs_to :merch, class_name: 'User', foreign_key: :user_id

  # NOTE: La dépendance 'dependent: :destroy' doit être définie dans le modèle User (has_one)

  # ============================================================
  # VALIDATIONS
  # ============================================================
  validates :merch, presence: true

  # Validation du canal de contact préféré
  validates :preferred_contact_channel,
            inclusion: { in: %w[phone email message none], message: "%{value} n'est pas un canal de contact valide" },
            allow_nil: true

  # Validation des booléens non-nullables (ceux qui ont null: false dans le schéma)
  validates :allow_identity, :share_address, :role_merch, :role_anim,
            :accept_mission_proposals,
            inclusion: { in: [true, false] }

  # Validation des booléens nullables (ceux qui peuvent être NULL dans le schéma)
  validates :allow_contact_email, :allow_contact_message, :allow_contact_phone, :share_planning, :allow_none,
            inclusion: { in: [true, false] },
            allow_nil: true


  # ============================================================
  # MÉTHODES UTILITAIRES (Toggle)
  # ============================================================

  # Visibilité de l'identité
  def toggle_identity!
    toggle!(:allow_identity)
  end

  # Partage de l'adresse
  def toggle_share_address!
    toggle!(:share_address)
  end

  def toggle_share_planning!
    toggle!(:share_planning)
  end

  # Autorisation de contact par email
  def toggle_allow_email!
    toggle!(:allow_contact_email)
  end

  # Autorisation de contact par téléphone
  def toggle_allow_phone!
    toggle!(:allow_contact_phone)
  end

  # Autorisation de contact par message
  def toggle_allow_message!
    toggle!(:allow_contact_message)
  end

  # Accepte les propositions de missions
  def toggle_accept_mission_proposals!
    toggle!(:accept_mission_proposals)
  end

  # Préférence : missions de Merchandising
  def toggle_role_merch!
    toggle!(:role_merch)
  end

  # Préférence : missions d'Animation
  def toggle_role_anim!
    toggle!(:role_anim)
  end

  # ============================================================
  # MÉTHODES D'AFFICHAGE
  # ============================================================

  # Affiche les préférences de missions actuelles
  def mission_preferences
    preferences = []
    preferences << 'Merchandising' if role_merch?
    preferences << 'Animation/Démonstration' if role_anim?

    return 'Aucun rôle sélectionné' if preferences.empty?

    preferences.join(' et ')
  end
end
