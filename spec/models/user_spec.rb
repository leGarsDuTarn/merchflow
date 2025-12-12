require "rails_helper"

RSpec.describe User, type: :model do

  before(:each) do
    # Création de l'agence par défaut pour que les factories de Contract fonctionnent
    Agency.find_or_create_by!(code: 'actiale', label: 'Actiale')
  end

  # ------------------------------------------------------------
  # FACTORY
  # ------------------------------------------------------------
  context 'Test de la factory' do
    it 'La factory est valide' do
      expect(build(:user)).to be_valid
    end
  end

  # ------------------------------------------------------------
  # RELATIONS
  # ------------------------------------------------------------
  context 'Test des associations' do
    it { should have_many(:contracts).dependent(:destroy) }
    it { should have_many(:work_sessions).through(:contracts) }
    it { should have_many(:declarations).dependent(:destroy) }
  end

  # ------------------------------------------------------------
  # VALIDATIONS
  # ------------------------------------------------------------
  context 'Test des validations' do
    # --- présence ---
    it { should validate_presence_of(:firstname).with_message('Vous devez renseigner votre prénom') }
    it { should validate_presence_of(:lastname).with_message('Vous devez renseigner votre nom') }
    it { should validate_presence_of(:username).with_message("Vous devez choisir un nom d'utilisateur") }
    it { should validate_presence_of(:email).with_message('Veuillez renseigner un email.') }
    it { should validate_presence_of(:address).with_message('Vous devez renseigner une adresse') }
    it { should validate_presence_of(:zipcode).with_message('Vous devez renseigner un code postal') }
    it { should validate_presence_of(:city).with_message('Vous devez renseigner une ville') }

    # --- email ---
    it { should allow_value('test@example.com').for(:email) }
    it { should_not allow_value('invalid-email').for(:email).with_message('exemple : john@gmail.com') }

    # --- unicité ---
    subject { create(:user) }
    it { should validate_uniqueness_of(:email).case_insensitive.with_message('Cette adresse email est déjà utilisée') }
    it { should validate_uniqueness_of(:username).case_insensitive.with_message("Ce nom d'utilisateur est déjà pris") }

    # --- format username ---
    it { should allow_value('benjamin_12').for(:username) }

    it 'Le test refuse les caractères spéciaux' do
      User.skip_callback(:validation, :before, :normalize_username)
      user = build(:user, username: 'benjamin !')
      expect(user).to be_invalid
      expect(user.errors[:username]).to include('ne peut contenir que des lettres, chiffres, . _ ou -')
      User.set_callback(:validation, :before, :normalize_username)
    end

    # --- password fort ---
    context 'Test des validation du password' do
      it 'refuse un password trop faible' do
        user = build(:user, password: 'abc123')
        expect(user).not_to be_valid
        expect(user.errors[:password].first).to include('Doit contenir au moins 8')
      end

      it 'accepte un password fort' do
        user = build(:user, password: 'Password1!')
        expect(user).to be_valid
      end
    end
  end

  # ------------------------------------------------------------
  # CALLBACKS : normalisation
  # ------------------------------------------------------------
  context 'Test des callbacks & normalisation' do
    it 'normalise firstname & lastname' do
      user = create(:user, firstname: 'benJAmIn', lastname: 'grasSIano')
      expect(user.firstname).to eq('Benjamin')
      expect(user.lastname).to eq('Grassiano')
    end

    it "normalise l'email en minuscule" do
      user = create(:user, email: 'TEST@EMAIL.COM')
      expect(user.email).to eq('test@email.com')
    end

    it "normalise l'username (downcase + strip)" do
      user = create(:user, username: '  BeN_Jr  ')
      expect(user.username).to eq('ben_jr')
    end
  end

  # ------------------------------------------------------------
  # generate_username
  # ------------------------------------------------------------
  context 'Test de la methode generate_username' do
    it 'génère un username automatique si vide' do
      user = create(:user, username: nil, firstname: 'Jean', lastname: 'Dupont')
      expect(user.username).to start_with('jeandupont')
    end

    it 'ajoute un compteur si username déjà pris' do
      create(:user, username: 'jeandupont')
      user2 = create(:user, username: nil, firstname: 'Jean', lastname: 'Dupont')
      expect(user2.username).to match(/jeandupont\d+/)
    end
  end

  # ------------------------------------------------------------
  # MÉTHODES UTILITAIRES
  # ------------------------------------------------------------
  describe 'Test de la methode full_name' do
    it 'concatène firstname + lastname' do
      user = build(:user, firstname: 'Benjamin', lastname: 'Grassiano')
      expect(user.full_name).to eq('Benjamin Grassiano')
    end
  end

  describe 'Test de la methode full_address' do
    it "renvoie l'adresse complète" do
      user = build(:user, address: "11 route d'Albi", zipcode: '81350', city: 'Valderiès')
      expect(user.full_address).to eq("11 route d'Albi, 81350, Valderiès")
    end
  end

  context 'Test des methodes address_complete?' do
    it 'renvoie true si les 3 champs sont présents' do
      user = build(:user, address: 'a', zipcode: 'b', city: 'c')
      expect(user.address_complete?).to be true
    end

    it 'renvoie false si un champ manque' do
      user = User.new(address: nil, zipcode: 'b', city: 'c')
      expect(user.address_complete?).to be false
    end
  end

  # ------------------------------------------------------------
  # MÉTHODES DASHBOARD
  # ------------------------------------------------------------
  context 'Test des methodes du dashboard' do
    let(:user) { create(:user) }
    let(:contract) { create(:contract, user: user) }

    before do
      allow_any_instance_of(Contract).to receive(:ifm_cp_total).and_return(10)
      allow_any_instance_of(Contract).to receive(:ifm).and_return(5)
      allow_any_instance_of(Contract).to receive(:cp).and_return(5)
      allow_any_instance_of(Contract).to receive(:km_payment).and_return(10)
    end

    let!(:session_current) do
      create(:work_session,
        contract: contract,
        date: Date.current,
        start_time: DateTime.current.change(hour: 9, min: 0),
        end_time: DateTime.current.change(hour: 11, min: 0), # 2h
        hourly_rate: 50.0, # ← C'est un attribut de WorkSession, pas de Contract
        km_custom: 20
      )
    end

    let!(:session_old) do
      create(:work_session,
        contract: contract,
        date: 2.months.ago,
        start_time: 2.months.ago.change(hour: 9, min: 0),
        end_time: 2.months.ago.change(hour: 10, min: 0), # 1h
        hourly_rate: 50.0,
        km_custom: 10
    )
    end

    # --- TOTAUX GLOBAUX (Current + Old) ---

    it 'total_hours_worked : somme de toutes les heures' do
      expect(user.total_hours_worked).to eq(3.0)
    end

    it 'total_brut : somme de tout le brut' do
     expect(user.total_brut).to eq(150.0)
    end

    it 'total_km : somme des km' do
      expect(user.total_km).to eq(30.0)
    end

    # --- TOTAUX MOIS EN COURS (Current uniquement) ---

    it 'sessions_this_month : ne récupère que la session du mois' do
      expect(user.sessions_this_month).to include(session_current)
      expect(user.sessions_this_month).not_to include(session_old)
    end

    it 'total_hours_this_month : heures du mois courant' do
      expect(user.total_hours_this_month).to eq(2.0)
    end

    it 'total_brut_this_month : brut du mois courant' do
      expect(user.total_brut_this_month).to eq(100.0)
    end

    it 'net_estimated_this_month : calculé sur le mois courant (78% du brut)' do
      # 100 * 0.78 = 78
      expect(user.net_estimated_this_month).to eq(78.0)
    end

    it 'net_total_estimated_this_month : net estimé + frais km du mois' do
      expect(user.net_total_estimated_this_month).to eq(88.0)
    end
  end
end
