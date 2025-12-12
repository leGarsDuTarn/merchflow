require 'rails_helper'

RSpec.describe FveInvitation, type: :model do

  # ------------------------------------------------------------
  # 1. FACTORY
  # ------------------------------------------------------------
  context 'Validité de base' do
    it 'a une factory valide' do
      expect(build(:fve_invitation)).to be_valid
    end
  end

  # ------------------------------------------------------------
  # 2. CALLBACKS (Génération Automatique - Anti-Crash)
  # ------------------------------------------------------------
  describe 'Callbacks de création' do
    it 'génère automatiquement un token sécurisé avant la création' do
      # Création sans fournir de token
      invit = build(:fve_invitation, token: nil)
      invit.save

      expect(invit.token).to be_present
      expect(invit.token.length).to be >= 16 # SecureRandom.hex(16) fait 32 chars
    end

    it 'définit automatiquement une date d\'expiration (7 jours) avant la création' do
      invit = build(:fve_invitation, expires_at: nil)
      invit.save

      expect(invit.expires_at).to be_present
      # Vérifie que la date est bien dans le futur
      expect(invit.expires_at).to be > Time.current
      # Vérifie que c'est environ 7 jours
      expect(invit.expires_at.to_date).to eq(7.days.from_now.to_date)
    end
  end

  # ------------------------------------------------------------
  # 3. VALIDATIONS (Intégrité des Données)
  # ------------------------------------------------------------
  context 'Validations' do
    it { should validate_presence_of(:email).with_message(/doit renseigner un email/) }
    it { should validate_presence_of(:agency).with_message(/nom de l'agence/) }

    # Test format email
    it 'rejette un email invalide' do
      invit = build(:fve_invitation, email: 'mauvais-email')
      expect(invit).not_to be_valid
      expect(invit.errors[:email]).to include('Format email invalide.')
    end

    # Unicité du token
    describe 'Unicité Token' do
      let!(:existing) { create(:fve_invitation) }

      it 'ne permet pas deux tokens identiques' do
        # Force le token pour simuler une collision improbable
        duplicate = build(:fve_invitation, token: existing.token)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:token]).to include('Ce token existe déjà.')
      end
    end
  end

  # ------------------------------------------------------------
  # 4. LOGIQUE MÉTIER (Gestion d'État)
  # ------------------------------------------------------------
  describe 'Méthodes d\'état (expired? / usable?)' do
    let(:invitation) { build(:fve_invitation, used: false, expires_at: 1.day.from_now) }

    context '#expired?' do
      it 'retourne false si la date est dans le futur' do
        expect(invitation.expired?).to be false
      end

      it 'retourne true si la date est passée' do
        invitation.expires_at = 1.minute.ago
        expect(invitation.expired?).to be true
      end
    end

    context '#usable?' do
      it 'est utilisable si non utilisée et non expirée' do
        expect(invitation.usable?).to be true
      end

      it 'n\'est pas utilisable si déjà utilisée' do
        invitation.used = true
        expect(invitation.usable?).to be false
      end

      it 'n\'est pas utilisable si expirée' do
        invitation.expires_at = 1.minute.ago
        expect(invitation.usable?).to be false
      end
    end
  end

  # ------------------------------------------------------------
  # 5. SCOPES (Filtrage)
  # ------------------------------------------------------------
  describe 'Scope .active' do
    # Cas 1 : Active (Futur + Non utilisée)
    let!(:active_invit) { create(:fve_invitation, used: false, expires_at: 1.day.from_now) }
    # Cas 2 : Déjà utilisée
    let!(:used_invit)   { create(:fve_invitation, used: true, expires_at: 1.day.from_now) }
    # Cas 3 : Expirée
    let!(:expired_invit){ create(:fve_invitation, used: false, expires_at: 1.day.ago) }

    it 'ne retourne que les invitations non utilisées et valides' do
      results = FveInvitation.active

      expect(results).to include(active_invit)
      expect(results).not_to include(used_invit)
      expect(results).not_to include(expired_invit)
    end
  end
end
