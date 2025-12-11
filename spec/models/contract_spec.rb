require 'rails_helper'

RSpec.describe Contract, type: :model do

  # --- CORRECTIF ICI : CRÉATION DE LA DÉPENDANCE ---
  before(:each) do
    # Création de l'agence 'actiale' car la factory l'utilise par défaut
    # et la validation du modèle vérifie son existence en DB.
    Agency.find_or_create_by!(code: 'actiale', label: 'Actiale')
  end

  # ------------------------------------------------------------
  # FACTORY
  # ------------------------------------------------------------
  context 'Test de la factory' do
    it 'La factory est valide' do
      expect(build(:contract)).to be_valid
    end
  end

  # ------------------------------------------------------------
  # ASSOCIATIONS
  # ------------------------------------------------------------
  context 'Test des associations' do
    it { should belong_to(:user) }
    it { should have_many(:work_sessions).dependent(:destroy) }
    it { should have_many(:declarations).dependent(:destroy) }
  end

  # ------------------------------------------------------------
  # ENUMS (string enums)
  # ------------------------------------------------------------
  context 'Test des agences et des labels' do
    it 'contient les bons contract_type' do
      expect(Contract.contract_types.keys).to include(
        'cdd', 'cidd', 'interim'
      )
    end

    it 'retourne les agences disponibles en base de données' do
      # L'agence Actiale est déjà créée par le before(:each)
      # Création d'une autre pour être sûr
      Agency.create!(code: 'rma', label: 'RMA')

      options = Contract.agency_options

      # On vérifie le format [Label, code]
      expect(options).to include(["Actiale", "actiale"])
      expect(options).to include(["RMA", "rma"])
    end
  end

  # ------------------------------------------------------------
  # VALIDATIONS
  # ------------------------------------------------------------
  context 'Test des validations' do
    it { should validate_presence_of(:agency).with_message('Vous devez sélectionner une agence') }
    it { should validate_numericality_of(:night_rate).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:ifm_rate).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:cp_rate).is_greater_than_or_equal_to(0) }
    it { should validate_presence_of(:km_rate) }
    it { should validate_numericality_of(:km_rate) }
    it { should validate_numericality_of(:km_limit).is_greater_than_or_equal_to(0) }
  end

  # ------------------------------------------------------------
  # LABELS AGENCY
  # ------------------------------------------------------------
  describe 'Test de agency_label' do
    it 'retourne le label correct' do
      contract = build(:contract, agency: :actiale)
      expect(contract.agency_label).to eq('Actiale')
    end
  end

  describe 'Test de agency_options' do
    it 'retourne un tableau de [label, clé]' do
      result = Contract.agency_options
      expect(result).to include(["Actiale", "actiale"])
    end
  end

  # ------------------------------------------------------------
  # LABELS CONTRACT TYPE
  # ------------------------------------------------------------
  describe 'Test du contract_type_label' do
    it 'retourne le label correct' do
      contract = build(:contract, contract_type: :cdd)
      expect(contract.contract_type_label).to eq('CDD')
    end
  end

  # ------------------------------------------------------------
  # MÉTHODES IFM / CP
  # ------------------------------------------------------------
  context 'Test des méthodes IFM / CP' do
    let(:contract) { build(:contract, ifm_rate: 0.1, cp_rate: 0.1) }

    it { expect(contract.ifm(100)).to eq(10.0) }
    it { expect(contract.cp(100)).to eq(10.0) }
    it { expect(contract.ifm_cp_total(100)).to eq(20.0) }
  end

  # ------------------------------------------------------------
  # MÉTHODES KM
  # ------------------------------------------------------------
  context 'Test des méthodes KM' do
    let(:contract) { build(:contract, km_rate: 0.5, km_limit: 10, km_unlimited: false) }

    describe 'compute_km' do
      it 'retourne distance si recommended = true' do
        expect(contract.compute_km(20, recommended: true)).to eq(20)
      end

      it 'respecte la limite km' do
        expect(contract.compute_km(30)).to eq(10)
      end

      it 'retourne distance si distance <= limite' do
        expect(contract.compute_km(8)).to eq(8)
      end

      it 'ignore la limite si km_unlimited = true' do
        unlimited = build(:contract, km_unlimited: true)
        expect(unlimited.compute_km(50)).to eq(50)
      end
    end

    describe 'km_payment' do
      it 'calcule le paiement' do
        expect(contract.km_payment(10)).to eq(5.0)
      end
    end
  end
end
