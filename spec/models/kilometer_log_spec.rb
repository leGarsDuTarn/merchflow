require 'rails_helper'

RSpec.describe KilometerLog, type: :model do

  # --- CORRECTIF ICI : CRÉATION DE LA DÉPENDANCE AGENCE ---
  before(:each) do
    # Nécessaire car create(:work_session) -> crée un Contract -> qui valide l'existence de l'Agence
    Agency.find_or_create_by!(code: 'actiale', label: 'Actiale')
  end
  # --------------------------------------------------------

  # ------------------------------------------------------------
  # FACTORY
  # ------------------------------------------------------------
  context 'Test de la factory' do
    it 'La factory est valide' do
      expect(build(:kilometer_log)).to be_valid
    end
  end

  # ------------------------------------------------------------
  # ASSOCIATIONS
  # ------------------------------------------------------------
  context 'Test des associations' do
    it { should belong_to(:work_session) }
  end

  # ------------------------------------------------------------
  # VALIDATIONS
  # ------------------------------------------------------------
  context 'Test des validations' do
    it { should validate_numericality_of(:distance).is_greater_than_or_equal_to(0).with_message('ne peut pas être négative') }

    # Attention : Assurez-vous que votre factory définit un km_rate > 0 (la db a 0.29 par défaut donc ça devrait aller)
    it { should validate_numericality_of(:km_rate).is_greater_than(0).with_message('doit être supérieur à 0') }

    it { should validate_length_of(:description).is_at_most(255) }
  end

  # ------------------------------------------------------------
  # CALLBACK normalize_description
  # ------------------------------------------------------------
  describe 'Callback normalize_description' do
    it 'supprime les espaces avant/après la description' do
      log = build(:kilometer_log, description: '  trajet domicile-magasin  ')
      log.valid?
      expect(log.description).to eq('trajet domicile-magasin')
    end

    it 'fonctionne même si description est nil' do
      log = build(:kilometer_log, description: nil)
      log.valid?
      expect(log.description).to eq("")
    end
  end

  # ------------------------------------------------------------
  # CALLBACK update_work_session_km
  # ------------------------------------------------------------
  describe 'Callback update_work_session_km' do
    # Pour tester les callbacks, on a besoin que la WorkSession soit valide et sauvegardée
    let(:ws) { create(:work_session) }

    it 'appelle compute_effective_km sur la WorkSession associée (after_save)' do
      log = build(:kilometer_log, work_session: ws)

      # On espionne la méthode sur l'objet ws
      # NOTE: Si WorkSession n'a pas encore la méthode compute_effective_km, ce test échouera avec NoMethodError
      expect(ws).to receive(:compute_effective_km)
      expect(ws).to receive(:save!)

      log.save
    end

    it 'appelle compute_effective_km après destruction (after_destroy)' do
      log = create(:kilometer_log, work_session: ws)

      expect(ws).to receive(:compute_effective_km)
      expect(ws).to receive(:save!)

      log.destroy
    end
  end

  # ------------------------------------------------------------
  # MISE À JOUR RÉELLE DES KM SUR WORKSESSION
  # ------------------------------------------------------------
  describe 'Mise à jour réelle des km_effectifs' do
    it 'met à jour les km_effectifs de la work_session' do
      # On s'assure que la session démarre propre
      # Note: Si WorkSession n'a pas la logique "has_many :kilometer_logs", ce test peut échouer
      target_ws = create(:work_session, km_custom: nil)

      # Création des logs -> déclenche les callbacks
      create(:kilometer_log, work_session: target_ws, distance: 10, km_rate: 0.5)
      create(:kilometer_log, work_session: target_ws, distance: 5, km_rate: 0.5)

      # On recharge l'objet depuis la DB pour voir les changements
      target_ws.reload

      # Ce test suppose que WorkSession#compute_effective_km fait la somme des logs
      expect(target_ws.effective_km).to eq(15.0)
    end
  end
end
