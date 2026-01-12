require 'rails_helper'

RSpec.describe MerchSetting, type: :model do

  # --- PRÉREQUIS ---
  before(:each) do
    # Nécessaire pour créer l'utilisateur associé au setting
    Agency.find_or_create_by!(code: 'actiale', label: 'Actiale')
  end

  # ------------------------------------------------------------
  # 1. FACTORY & ASSOCIATIONS
  # ------------------------------------------------------------
  context 'Validité et Structure' do
    it 'a une factory valide' do
      expect(build(:merch_setting)).to be_valid
    end

    # Vérifie le lien avec User
    it { should belong_to(:merch).class_name('User').with_foreign_key(:user_id) }
  end

  # ------------------------------------------------------------
  # 2. VALIDATIONS (Sécurité des Données)
  # ------------------------------------------------------------
  context 'Validations' do
    # Protection contre les orphelins
    it { should validate_presence_of(:merch) }

    # Protection contre les valeurs fausse qui feraient planter l'UI
    describe 'preferred_contact_channel' do

      it 'rejette une valeur invalide' do
        setting = build(:merch_setting, preferred_contact_channel: 'pigeon')
        expect(setting).not_to be_valid
        expect(setting.errors[:preferred_contact_channel]).to include("pigeon n'est pas un canal de contact valide")
      end

      it 'accepte nil (allow_nil: true)' do
        setting = build(:merch_setting, preferred_contact_channel: nil)
        expect(setting).to be_valid
      end
    end
  end

  # ------------------------------------------------------------
  # 3. LOGIQUE MÉTIER (Toggle)
  # ------------------------------------------------------------
  describe 'Méthodes Toggle (Bascule)' do
    let(:setting) { create(:merch_setting, allow_identity: false) }

    it 'toggle_identity! inverse la valeur et sauvegarde' do
      expect { setting.toggle_identity! }.to change { setting.reload.allow_identity }.from(false).to(true)
    end

    it 'toggle_share_address! inverse la valeur' do
      setting.share_address = false
      setting.save
      expect { setting.toggle_share_address! }.to change { setting.reload.share_address }.from(false).to(true)
    end

    # On teste un toggle nullable pour être sûr
    it 'toggle_allow_email! gère les valeurs nulles comme false au départ' do
      setting.allow_contact_email = nil
      setting.save
      # nil -> true
      setting.toggle_allow_email!
      expect(setting.reload.allow_contact_email).to be true
    end
  end

  # ------------------------------------------------------------
  # 4. LOGIQUE D'AFFICHAGE
  # ------------------------------------------------------------
  describe 'mission_preferences' do
    let(:setting) { build(:merch_setting) }

    it 'affiche "Merchandising" si seul role_merch est actif' do
      setting.role_merch = true
      setting.role_anim = false
      expect(setting.mission_preferences).to eq('Merchandising')
    end

    it 'affiche "Animation/Démonstration" si seul role_anim est actif' do
      setting.role_merch = false
      setting.role_anim = true
      expect(setting.mission_preferences).to eq('Animation/Démonstration')
    end

    it 'affiche les deux avec un "et" si les deux sont actifs' do
      setting.role_merch = true
      setting.role_anim = true
      expect(setting.mission_preferences).to eq('Merchandising et Animation/Démonstration')
    end

    it 'affiche "Aucun rôle sélectionné" si rien n\'est coché (évite de renvoyer vide)' do
      setting.role_merch = false
      setting.role_anim = false
      expect(setting.mission_preferences).to eq('Aucun rôle sélectionné')
    end
  end
end
