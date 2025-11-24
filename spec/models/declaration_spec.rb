require 'rails_helper'

RSpec.describe Declaration, type: :model do

  # ------------------------------------------------------------
  # FACTORY
  # ------------------------------------------------------------
  context 'Test de la factory' do
    it 'La factory est valide' do
      expect(build(:declaration)).to be_valid
    end
  end

  # ------------------------------------------------------------
  # ASSOCIATIONS
  # ------------------------------------------------------------
  context 'Test des associations' do
    it { should belong_to(:user) }
    it { should belong_to(:contract) }
  end

  # ------------------------------------------------------------
  # VALIDATIONS
  # ------------------------------------------------------------
  context 'Test des validations' do

    it { should validate_presence_of(:month) }
    it { should validate_inclusion_of(:month).in_range(1..12).with_message('mois invalide') }

    it { should validate_presence_of(:year) }
    it {
      should validate_numericality_of(:year)
        .only_integer
        .is_greater_than_or_equal_to(2000)
        .with_message('année invalide')
    }

    it {
      should validate_presence_of(:employer_name)
        .with_message("le nom de l'employeur est obligatoire")
    }

    it {
      should validate_numericality_of(:total_minutes)
        .is_greater_than_or_equal_to(0)
        .with_message('les minutes doivent être positives')
    }

    it {
      should validate_numericality_of(:brut_with_cp)
        .is_greater_than_or_equal_to(0)
        .with_message('le montant doit être positif')
    }

    # --- CORRECTIF ICI ---
    describe 'unicité user/year/month/contract' do
      let(:user) { create(:user) }
      let(:contract) { create(:contract, user: user) }

      let!(:existing_declaration) do
        create(:declaration,
          user: user,
          contract: contract,
          year: 2024,
          month: 10
        )
      end

      subject do
        build(:declaration,
          user: user,
          contract: contract,
          year: 2024,
          month: 10
        )
      end

      it 'ne permet pas de créer un doublon' do
        expect(subject).not_to be_valid
        expect(subject.errors[:user_id]).to include('une déclaration existe déjà pour ce mois et cet employeur')
      end
    end
  end

  # ------------------------------------------------------------
  # CALLBACKS
  # ------------------------------------------------------------
  context 'Test des CALLBACKS' do
    describe 'Callback set_employer_name' do
      it 'remplit automatiquement employer_name si vide' do
        contract = build(:contract, agency: :actiale)
        declaration = build(:declaration, contract: contract, employer_name: nil)

        declaration.valid?

        expect(declaration.employer_name).to eq('Actiale')
      end

      it 'ne modifie pas employer_name si déjà renseigné' do
        declaration = build(:declaration, employer_name: 'Mon Employeur')

        declaration.valid?

        expect(declaration.employer_name).to eq('Mon Employeur')
      end
    end
  end

  # ------------------------------------------------------------
  # MÉTHODES UTILITAIRES
  # ------------------------------------------------------------
  context 'Test des méthodes' do

    describe 'Test méthode total_hours' do
      it 'convertit les minutes en heures décimales (arrondi 2 décimales)' do
        decl = build(:declaration, total_minutes: 135)
        expect(decl.total_hours).to eq(2.25)
      end
    end

    describe 'Test méthode period_label' do
      it 'retourne mm/yyyy avec zero-padding' do
        decl = build(:declaration, month: 3, year: 2024)
        expect(decl.period_label).to eq('03/2024')
      end
    end

    describe 'Test méthode employeur' do
      it 'retourne employer_name si présent' do
        decl = build(:declaration, employer_name: 'Mon Employeur')
        expect(decl.employer).to eq('Mon Employeur')
      end

      it 'retourne agency_label du contract si employer_name absent' do
        contract = build(:contract, agency: :cpm)
        decl = build(:declaration, employer_name: nil, contract: contract)
        expect(decl.employer).to eq('CPM')
      end

      it "retourne 'Employeur inconnu' si contract manquant + employer_name nil" do
        decl = build(:declaration, employer_name: nil, contract: nil)
        expect(decl.employer).to eq('Employeur inconnu')
      end
    end
  end
end
