require 'rails_helper'

RSpec.describe KilometerLog, type: :model do

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
    it 'appelle compute_effective_km sur la WorkSession associée (after_save)' do
      ws = create(:work_session)

      log = build(:kilometer_log, work_session: ws)

      # On surveille l’appel
      expect(ws).to receive(:compute_effective_km)
      expect(ws).to receive(:save!)

      log.save
    end

    it 'appelle compute_effective_km après destruction (after_destroy)' do
      ws = create(:work_session)
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
      ws = create(:work_session, km_custom: nil)

      create(:kilometer_log, work_session: ws, distance: 10, km_rate: 0.5)
      create(:kilometer_log, work_session: ws, distance: 5, km_rate: 0.5)

      ws.reload

      expect(ws.effective_km).to eq(15.0)
    end
  end
end
