require 'rails_helper'

RSpec.describe Contract, type: :model do

  # --- SETUP ESSENTIEL ---
  # 1. Créer la dépendance Agence en DB
  before(:each) do
    Agency.find_or_create_by!(code: 'actiale', label: 'Actiale')
  end

  # 2. DÉFINIR LE SUJET : Crucial pour que shoulda-matchers fonctionne
  # Cela assure que les validations sont testées sur un objet qui a déjà un User et une Agence valides.
  subject { build(:contract) }

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
  # ENUMS & LISTES
  # ------------------------------------------------------------
  context 'Test des agences et des labels' do
    it 'contient les bons contract_type' do
      expect(Contract.contract_types.keys).to include(
        'cdd', 'cidd', 'interim'
      )
    end

    it 'retourne les agences disponibles en base de données' do
      Agency.find_or_create_by!(code: 'rma', label: 'RMA')
      options = Contract.agency_options

      expect(options).to include(["Actiale", "actiale"])
      expect(options).to include(["RMA", "rma"])
    end
  end

  # ------------------------------------------------------------
  # VALIDATIONS
  # ------------------------------------------------------------
  context 'Test des validations' do
    it { should validate_presence_of(:agency).with_message('Vous devez sélectionner une agence') }

    # Note : Le format '0.0' vs 'abcd' est parfois capricieux avec les types Decimal en Rails + RSpec.
    # Si ces tests échouent encore après l'ajout de 'subject', c'est souvent dû au casting automatique de Rails.
    # Mais essayons avec un sujet valide d'abord.
    it { should validate_numericality_of(:night_rate).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:ifm_rate).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:cp_rate).is_greater_than_or_equal_to(0) }
    it { should validate_presence_of(:km_rate) }
    it { should validate_numericality_of(:km_rate) }
    it { should validate_numericality_of(:km_limit).is_greater_than_or_equal_to(0) }
  end

  # ------------------------------------------------------------
  # LABELS
  # ------------------------------------------------------------
  describe 'Helpers de label' do
    it 'agency_label retourne le bon texte' do
      contract = build(:contract, agency: :actiale)
      expect(contract.agency_label).to eq('Actiale')
    end

    it 'contract_type_label retourne le bon texte' do
      contract = build(:contract, contract_type: :cdd)
      expect(contract.contract_type_label).to eq('CDD')
    end
  end

  # ------------------------------------------------------------
  # LOGIQUE MÉTIER : IFM / CP
  # ------------------------------------------------------------
 context 'Calculs IFM / CP' do
    # On passe en base 100 : 10.0 = 10%
    let(:contract) { build(:contract, ifm_rate: 10.0, cp_rate: 10.0) }

    it 'calcule l\'IFM correctement' do
      expect(contract.ifm(100)).to eq(10.0)
    end

    it 'calcule les CP correctement' do
      expect(contract.cp(100)).to eq(10.0)
    end

    it 'calcule le total IFM + CP' do
      expect(contract.ifm_cp_total(100)).to eq(20.0)
    end

    it 'est invalide si le taux dépasse 50% (sécurité)' do
      contract.ifm_rate = 51
      expect(contract).not_to be_valid
      expect(contract.errors[:ifm_rate]).to be_present
    end
  end

  # ------------------------------------------------------------
  # LOGIQUE MÉTIER : KILOMÈTRES (Strict)
  # ------------------------------------------------------------
  context 'Calculs Kilométriques' do
    # Configuration : 0.5€/km, Limite à 10km, Pas illimité
    let(:contract) { build(:contract, km_rate: 0.5, km_limit: 10, km_unlimited: false) }

    describe '#compute_km (Calcul de la distance effective)' do
      it 'retourne la distance réelle si recommended = true (même si > limite)' do
        # 20km réels > 10km limite, mais recommandé => 20 retenus
        expect(contract.compute_km(20, recommended: true)).to eq(20)
      end

      it 'plafonne à la limite si dépassement standard' do
        # 30km réels > 10km limite => 10 retenus
        expect(contract.compute_km(30)).to eq(10)
      end

      it 'retourne la distance réelle si sous la limite' do
        # 8km réels < 10km limite => 8 retenus
        expect(contract.compute_km(8)).to eq(8)
      end

      it 'ignore la limite si le contrat est en km illimités' do
        unlimited_contract = build(:contract, km_unlimited: true, km_limit: 10)
        expect(unlimited_contract.compute_km(50)).to eq(50)
      end
    end

    describe '#km_payment (Calcul financier)' do
      it 'calcule le montant correct (Distance effective * Taux)' do
        # Limite de 10km * 0.5€ = 5.0€
        expect(contract.km_payment(20)).to eq(5.0)
      end

      it 'calcule le montant correct pour un trajet recommandé' do
        # 20km * 0.5€ = 10.0€
        expect(contract.km_payment(20, recommended: true)).to eq(10.0)
      end
    end
  end
end
