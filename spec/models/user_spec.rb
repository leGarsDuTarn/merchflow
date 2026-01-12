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
    it { should allow_value('zen-renard-4231').for(:username) }

    it 'Le test refuse les caractères spéciaux non autorisés' do
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
  # generate_username (Mise à jour pour Confidentialité)
  # ------------------------------------------------------------
  context 'Test de la methode generate_username' do
    it 'génère un username anonyme respectant le pattern (mot-mot-chiffres)' do
      user = create(:user, username: nil)
      # Format attendu : adjectif-nom-4chiffres (ex: rapide-faucon-1234)
      expect(user.username).to match(/[a-z]+-[a-z]+-\d{4}/)
    end

    it 'génère des usernames différents pour deux utilisateurs sans lien avec leur identité' do
      user1 = create(:user, username: nil, firstname: 'Jean', lastname: 'Dupont')
      user2 = create(:user, username: nil, firstname: 'Jean', lastname: 'Dupont')

      expect(user1.username).not_to eq(user2.username)
      expect(user1.username).not_to include('jean')
      expect(user1.username).not_to include('dupont')
    end

    it 'ne modifie pas un username déjà renseigné par l utilisateur' do
      user = create(:user, username: 'mon-pseudo-perso')
      expect(user.username).to eq('mon-pseudo-perso')
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
      # On mocke les calculs du contrat pour maîtriser les chiffres
      allow_any_instance_of(Contract).to receive(:ifm).and_return(5.0)
      allow_any_instance_of(Contract).to receive(:cp).and_return(5.0)
      allow_any_instance_of(Contract).to receive(:km_payment).and_return(10.0)
    end

    let!(:session_current) do
      create(:work_session,
        contract: contract,
        date: Date.current,
        start_time: DateTime.current.change(hour: 9, min: 0),
        end_time: DateTime.current.change(hour: 11, min: 0), # 2h de travail
        hourly_rate: 50.0, # Total Base = 100€
        km_custom: 20
      )
    end

    let!(:session_old) do
      create(:work_session,
        contract: contract,
        date: 2.months.ago,
        start_time: 2.months.ago.change(hour: 9, min: 0),
        end_time: 2.months.ago.change(hour: 10, min: 0), # 1h de travail
        hourly_rate: 50.0,
        km_custom: 10
    )
    end

    # --- TOTAUX GLOBAUX ---
    it 'total_hours_worked : somme de toutes les heures' do
      expect(user.total_hours_worked).to eq(3.0)
    end

    it 'total_brut : somme de tout le brut de base' do
      expect(user.total_brut).to eq(150.0)
    end

    it 'total_km : somme des km' do
      expect(user.total_km).to eq(30.0)
    end

    # --- TOTAUX MOIS EN COURS ---
    it 'sessions_this_month : ne récupère que la session du mois' do
      expect(user.sessions_this_month).to include(session_current)
      expect(user.sessions_this_month).not_to include(session_old)
    end

    it 'total_hours_for_month : heures du mois courant' do
      expect(user.total_hours_for_month(Date.current)).to eq(2.0)
    end

    it 'total_complete_brut_for_month : brut complet (Base + IFM + CP)' do
      expect(user.total_complete_brut_for_month(Date.current)).to eq(110.0)
    end

    it 'net_total_estimated_for_month : Somme exacte des nets' do
      # 100 * 0.78 (78.0) + 5 * 0.78 (3.9) + 5 * 0.78 (3.9) + 10.0 (KM) = 95.8
      expect(user.net_total_estimated_for_month(Date.current)).to eq(95.8)
    end
  end

  # ------------------------------------------------------------
  # GESTION DES CONFLITS & INDISPONIBILITÉS
  # ------------------------------------------------------------
  describe 'Gestion des conflits' do
    let(:merch) { create(:user) }

    # Setup pour conflicting_work_sessions
    let(:contract) { create(:contract, user: merch) }
    let(:existing_offer) { create(:job_offer) }
    # Session acceptée demain de 14h à 18h
    let!(:existing_session) do
      create(:work_session,
        contract: contract,
        job_offer: existing_offer,
        date: Date.tomorrow,
        start_time: Time.zone.parse("14:00"),
        end_time: Time.zone.parse("18:00"),
        status: 'accepted'
      )
    end

    describe '#conflicting_work_sessions' do
      it 'détecte un conflit si les horaires se chevauchent' do
        new_offer = create(:job_offer)
        new_offer.job_offer_slots.destroy_all
        # Correction : on utilise Date.tomorrow au lieu de test_date
        create(:job_offer_slot, job_offer: new_offer, date: Date.tomorrow, start_time: "15:00", end_time: "17:00")

      new_offer.reload
      expect(merch.conflicting_work_sessions(new_offer)).to include(existing_session)
      end
    end

    describe '#has_unavailability_during?' do
      it 'retourne true si une indisponibilité tombe sur la date de l\'offre' do
        create(:unavailability, user: merch, date: Date.tomorrow)
        offer = create(:job_offer)
        offer.job_offer_slots.destroy_all
        create(:job_offer_slot, job_offer: offer, date: Date.tomorrow)

        # AJOUTER CETTE LIGNE :
        offer.reload

        expect(merch.has_unavailability_during?(offer)).to be true
      end
    end
  end
end
