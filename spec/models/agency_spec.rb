require 'rails_helper'

RSpec.describe Agency, type: :model do

  # ------------------------------------------------------------
  # 1. TEST DE BASE & FACTORY
  # ------------------------------------------------------------
  context 'Validité de base' do
    it 'a une factory valide' do
      expect(build(:agency)).to be_valid
    end
  end

  # ------------------------------------------------------------
  # 2. VALIDATIONS (Protection des données)
  # ------------------------------------------------------------
  context 'Validations' do
    # Création d'une agence en base pour tester l'unicité par rapport à elle
    before { create(:agency, code: 'ref-agency') }

    it { should validate_presence_of(:label) }

    # Le code est requis, même s'il est généré par callback
    it { should validate_presence_of(:code) }

    # Vérifie que 'REF-AGENCY' est rejeté si 'ref-agency' existe déjà
    it { should validate_uniqueness_of(:code).case_insensitive }
  end

  # ------------------------------------------------------------
  # 3. LOGIQUE MÉTIER : GÉNÉRATION & NETTOYAGE DU CODE
  # ------------------------------------------------------------
  describe 'Callbacks de nettoyage (Sanitization)' do

    context 'Quand le code est vide' do
      it 'génère automatiquement le code à partir du label' do
        agency = build(:agency, code: nil, label: 'Ma Super Agence')
        agency.save
        # "Ma Super Agence" -> "ma-super-agence"
        expect(agency.code).to eq('ma-super-agence')
      end

      it 'gère les caractères spéciaux et accents' do
        agency = build(:agency, code: nil, label: 'Hélène & Garçons')
        agency.save
        expect(agency.code).to eq('helene-garcons')
      end
    end

    context 'Quand le code est fourni manuellement' do
      it 'nettoie le code fourni (minuscules et sans espaces)' do
        # L'admin saisit "  PEPSICO  " -> doit devenir "pepsico"
        agency = build(:agency, code: '  PEPSICO  ', label: 'Pepsico France')
        agency.save
        expect(agency.code).to eq('pepsico')
      end

      it 'transforme les espaces internes en tirets' do
        agency = build(:agency, code: 'pepsico france', label: 'Pepsico')
        agency.save
        expect(agency.code).to eq('pepsico-france')
      end

      it 'priorise le code fourni sur le label' do
        # Si un code spécifique est donné, il ne doit pas être écrasé par le label
        agency = build(:agency, code: 'code-specifique', label: 'Autre Label')
        agency.save
        expect(agency.code).to eq('code-specifique')
      end
    end
  end

  # ------------------------------------------------------------
  # 4. ROBUSTESSE (Edge Cases)
  # ------------------------------------------------------------
  describe 'Robustesse' do
    it 'ne crash pas si le label est vide' do
      agency = build(:agency, label: nil, code: nil)
      # Le callback ne doit pas faire crasher l'app avec un "undefined method parameterize for nil"
      expect { agency.valid? }.not_to raise_error
      # Doit être invalide via validate_presence_of
      expect(agency).not_to be_valid
    end
  end
end
