require 'rails_helper'

RSpec.describe Favorite, type: :model do

  # --- PRÉREQUIS : AGENCE ---
  # Nécessaire car la factory :fve a besoin d'une agence
  before(:each) do
    Agency.find_or_create_by!(code: 'actiale', label: 'Actiale')
  end

  # ------------------------------------------------------------
  # 1. FACTORY
  # ------------------------------------------------------------
  context 'Validité de base' do
    it 'a une factory valide' do
      favorite = build(:favorite)
      expect(favorite).to be_valid
    end
  end

  # ------------------------------------------------------------
  # 2. ASSOCIATIONS (Structure)
  # ------------------------------------------------------------
  context 'Associations' do
    # Vérifie que les clés étrangères sont bien configurées
    it { should belong_to(:fve).class_name('User') }
    it { should belong_to(:merch).class_name('User') }
  end

  # ------------------------------------------------------------
  # 3. VALIDATIONS (Anti-Crash SQL)
  # ------------------------------------------------------------
  context 'Validations' do

    it 'est invalide sans FVE' do
      fav = build(:favorite, fve: nil)
      expect(fav).not_to be_valid
      # On vérifie qu'il y a une erreur sur le champ :fve, peu importe le texte (Français, Anglais ou manquant)
      expect(fav.errors[:fve]).not_to be_empty
    end

    it 'est invalide sans Merch' do
      fav = build(:favorite, merch: nil)
      expect(fav).not_to be_valid
      # Idem, on vérifie juste que l'erreur existe
      expect(fav.errors[:merch]).not_to be_empty
    end

    # --- TEST D'UNICITÉ CRITIQUE ---
    describe 'Unicité du couple FVE/Merch' do
      let(:fve_user) { create(:user, :fve) }
      let(:merch_user) { create(:user) }

      # Création d'un premier favori en base
      let!(:existing_favorite) { create(:favorite, fve: fve_user, merch: merch_user) }

      it 'empêche de mettre deux fois le même merch en favori pour la même FVE' do
        # Essaye de recréer exactement le même lien
        duplicate = build(:favorite, fve: fve_user, merch: merch_user)

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:fve_id]).to include("Ce merch est déjà dans vos favoris")
      end

      it 'autorise le même merch en favori pour une AUTRE FVE' do
        other_fve = create(:user, :fve, email: 'other@fve.com', username: 'other_fve')

        valid_fav = build(:favorite, fve: other_fve, merch: merch_user)
        expect(valid_fav).to be_valid
      end
    end
  end
end
