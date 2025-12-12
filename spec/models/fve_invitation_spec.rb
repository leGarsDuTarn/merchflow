require 'rails_helper'

RSpec.describe FveInvitation, type: :model do

  # ------------------------------------------------------------
  # 1. FACTORY
  # ------------------------------------------------------------
  context 'Validité de base' do
    it 'a une factory valide' do
      # Grâce au before_validation, build().valid? va générer le token
      expect(build(:fve_invitation)).to be_valid
    end
  end

  # ------------------------------------------------------------
  # 2. CALLBACKS (Génération Automatique)
  # ------------------------------------------------------------
  describe 'Callbacks de validation' do
    it 'génère automatiquement un token sécurisé lors de la validation' do
      invit = build(:fve_invitation, token: nil)
      # On appelle valid? pour déclencher before_validation
      invit.valid?

      expect(invit.token).to be_present
      expect(invit.token.length).to be >= 16
    end

    it 'définit automatiquement une date d\'expiration' do
      invit = build(:fve_invitation, expires_at: nil)
      invit.valid?

      expect(invit.expires_at).to be_present
      expect(invit.expires_at).to be > Time.current
    end
  end

  # ------------------------------------------------------------
  # 3. VALIDATIONS
  # ------------------------------------------------------------
  context 'Validations' do
    # On utilise subject pour aider shoulda matchers à avoir un objet valide de base
    subject { build(:fve_invitation) }

    it { should validate_presence_of(:email).with_message(/devez renseigner un email/) }
    it { should validate_presence_of(:agency).with_message(/nom de l'agence/) }

    it 'rejette un email invalide' do
      invit = build(:fve_invitation, email: 'mauvais-email')
      expect(invit).not_to be_valid
      expect(invit.errors[:email]).to include('Format email invalide.')
    end

    describe 'Unicité Token' do
      # Ici, create fonctionnera car le before_validation remplira les champs
      let!(:existing) { create(:fve_invitation) }

      it 'ne permet pas deux tokens identiques' do
        duplicate = build(:fve_invitation, token: existing.token)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:token]).to include('Ce token existe déjà.')
      end
    end
  end

  # ------------------------------------------------------------
  # 4. LOGIQUE MÉTIER & SCOPES
  # ------------------------------------------------------------
  # (Le reste de votre fichier de test était bon, pas besoin de le changer)
  describe 'Méthodes d\'état' do
    let(:invitation) { build(:fve_invitation, used: false, expires_at: 1.day.from_now) }

    it 'retourne true si expiré' do
      invitation.expires_at = 1.minute.ago
      expect(invitation.expired?).to be true
    end

    it 'est utilisable si tout est ok' do
      expect(invitation.usable?).to be true
    end
  end

  describe 'Scope .active' do
    let!(:active_invit) { create(:fve_invitation, used: false, expires_at: 1.day.from_now) }
    let!(:used_invit)   { create(:fve_invitation, used: true, expires_at: 1.day.from_now) }
    let!(:expired_invit){ create(:fve_invitation, used: false, expires_at: 1.day.ago) }

    it 'ne retourne que les invitations actives' do
      expect(FveInvitation.active).to include(active_invit)
      expect(FveInvitation.active).not_to include(used_invit)
      expect(FveInvitation.active).not_to include(expired_invit)
    end
  end
end
