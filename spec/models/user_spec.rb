require "rails_helper"

RSpec.describe User, type: :model do
  # ------------------------------------------------------------
  # FACTORY
  # ------------------------------------------------------------
  describe "factory" do
    it "has a valid factory" do
      # On vérifie que la factory :user est valide en l'état
      expect(build(:user)).to be_valid
    end
  end

  # ------------------------------------------------------------
  # RELATIONS
  # ------------------------------------------------------------
  describe "associations" do
    # has_many :contracts
    it { should have_many(:contracts).dependent(:destroy) }

    # has_many :work_sessions via :contracts
    it { should have_many(:work_sessions).through(:contracts) }

    # has_many :declarations
    it { should have_many(:declarations).dependent(:destroy) }
  end

  # ------------------------------------------------------------
  # VALIDATIONS
  # ------------------------------------------------------------
  describe "validations" do
    # --- présence ---
    it { should validate_presence_of(:firstname).with_message("Vous devez renseigner votre prénom") }
    it { should validate_presence_of(:lastname).with_message("Vous devez renseigner votre nom") }

    it { should validate_presence_of(:username).with_message("Vous devez choisir un nom d'utilisateur") }
    it { should validate_presence_of(:email).with_message("Veuillez renseigner un email.") }

    # --- email ---
    it do
      should allow_value("test@example.com").for(:email)
    end

    it do
      should_not allow_value("invalid-email").for(:email)
        .with_message("exemple : john@gmail.com")
    end

    # --- email unicité ---
    subject { create(:user) } # Obligatoire pour les tests d’unicité Shoulda
    it { should validate_uniqueness_of(:email).case_insensitive.with_message("Cette adresse email est déjà utilisée") }
    it { should validate_uniqueness_of(:username).case_insensitive.with_message("Ce nom d'utilisateur est déjà pris") }

    # --- format username ---
    it do
      should allow_value("benjamin_12").for(:username)
    end

    it do
      should_not allow_value("benjamin !").for(:username).strict
        .with_message("ne peut contenir que des lettres, chiffres, . _ ou -")
    end

    # --- password fort (regex) ---
    context "password validation" do
      it "refuse un password trop faible" do
        user = build(:user, password: "abc123")
        expect(user).not_to be_valid
        expect(user.errors[:password].first).to include("Doit contenir au moins 8")
      end

      it "accepte un password fort" do
        user = build(:user, password: "Password1!")
        expect(user).to be_valid
      end
    end
  end

  # ------------------------------------------------------------
  # CALLBACKS : normalisation
  # ------------------------------------------------------------
  describe "callbacks - normalisation" do
    it "normalise firstname & lastname" do
      user = create(:user, firstname: "benJAmIn", lastname: "grasSIano")
      expect(user.firstname).to eq("Benjamin")
      expect(user.lastname).to eq("Grassiano")
    end

    it "normalise email en minuscule" do
      user = create(:user, email: "TEST@EMAIL.COM")
      expect(user.email).to eq("test@email.com")
    end

    it "normalise username (downcase + strip)" do
      user = create(:user, username: "  BeN_Jr  ")
      expect(user.username).to eq("ben_jr")
    end
  end

  # ------------------------------------------------------------
  # generate_username
  # ------------------------------------------------------------
  describe "#generate_username" do
    it "génère un username automatique si vide" do
      user = create(:user, username: nil, firstname: "Jean", lastname: "Dupont")
      expect(user.username).to start_with("jeandupont")
    end

    it "ajoute un compteur si username déjà pris" do
      create(:user, username: "jeandupont")
      user2 = create(:user, username: nil, firstname: "Jean", lastname: "Dupont")
      expect(user2.username).to match(/jeandupont\d+/)
    end
  end

  # ------------------------------------------------------------
  # MÉTHODES UTILITAIRES
  # ------------------------------------------------------------
  describe "#full_name" do
    it "concatène firstname + lastname" do
      user = build(:user, firstname: "Benjamin", lastname: "Grassiano")
      expect(user.full_name).to eq("Benjamin Grassiano")
    end
  end

  describe "#full_address" do
    it "renvoie l'adresse complète" do
      user = build(:user, address: "11 route d'Albi", zipcode: "81350", city: "Valderiès")
      expect(user.full_address).to eq("11 route d'Albi, 81350, Valderiès")
    end
  end

  describe "#address_complete?" do
    it "renvoie true si les 3 champs sont présents" do
      user = build(:user, address: "a", zipcode: "b", city: "c")
      expect(user.address_complete?).to be true
    end

    it "renvoie false si un champ manque" do
      user = build(:user, address: nil)
      expect(user.address_complete?).to be false
    end
  end

  # ------------------------------------------------------------
  # MÉTHODES DASHBOARD
  # ------------------------------------------------------------
  describe "dashboard methods" do
    let(:user) { create(:user) }
    let(:contract) { create(:contract, user: user) }

    before do
      # On mock des work_sessions sans dépendre de la logique métier complète
      allow(user).to receive(:work_sessions).and_return([
        double(duration_minutes: 120, brut: 80, effective_km: 10, contract: contract, recommended: false),
        double(duration_minutes: 60, brut: 35, effective_km: 5, contract: contract, recommended: true)
      ])

      allow(contract).to receive(:ifm_cp_total).and_return(10)
      allow(contract).to receive(:km_payment).and_return(5)
    end

    it "#total_minutes_worked retourne la somme" do
      expect(user.total_minutes_worked).to eq(180)
    end

    it "#total_hours_worked retourne le total en heures" do
      expect(user.total_hours_worked).to eq(3.0)
    end

    it "#total_brut" do
      expect(user.total_brut).to eq(115)
    end

    it "#total_ifm_cp" do
      expect(user.total_ifm_cp).to eq(20)
    end

    it "#total_km" do
      expect(user.total_km).to eq(15)
    end

    it "#total_km_payment" do
      expect(user.total_km_payment).to eq(10)
    end
  end
end
