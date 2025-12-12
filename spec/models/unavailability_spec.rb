# spec/models/unavailability_spec.rb

require 'rails_helper'

RSpec.describe Unavailability, type: :model do

  # --- PRÉREQUIS ---
  # Création de l'agence nécessaire pour valider les Users/Contrats si needed
  before(:each) do
    Agency.find_or_create_by!(code: 'actiale', label: 'Actiale')
  end

  # ------------------------------------------------------------
  # 1. FACTORY & ASSOCIATIONS
  # ------------------------------------------------------------
  context 'Validité et Associations' do
    it 'a une factory valide' do
      expect(build(:unavailability)).to be_valid
    end

    it { should belong_to(:user) }
  end

  # ------------------------------------------------------------
  # 2. VALIDATIONS (Anti-Crash & Intégrité)
  # ------------------------------------------------------------
  context 'Validations de présence' do
    it { should validate_presence_of(:date) }
  end

  describe 'Unicité (user_id / date)' do
    let(:user) { create(:user) }

    # Création du premier enregistrement pour le test
    let!(:existing_unavailability) { create(:unavailability, user: user, date: Date.tomorrow) }

    it 'empêche de créer deux indisponibilités pour le même jour et le même user' do
      # Tentative de doublon
      duplicate = build(:unavailability, user: user, date: Date.tomorrow)

      expect(duplicate).not_to be_valid
      # Permet de vérifier que le message est bien sur le champ :date ou qu'il est présent sur :base
      expect(duplicate.errors[:date]).not_to be_empty
    end

    it 'autorise une indisponibilité le même jour pour un AUTRE user' do
      other_user = create(:user, username: 'user_different')
      valid_unavailability = build(:unavailability, user: other_user, date: Date.tomorrow)
      expect(valid_unavailability).to be_valid
    end

    it 'autorise une autre date pour le même user' do
      valid_unavailability = build(:unavailability, user: user, date: Date.tomorrow + 1.day)
      expect(valid_unavailability).to be_valid
    end
  end
end
