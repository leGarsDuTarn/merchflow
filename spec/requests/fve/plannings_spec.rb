require 'rails_helper'

RSpec.describe "Fve::Plannings", type: :request do
  # --- SETUP ---
  # Création de l'agence nécessaire pour valider les Users/Contrats
  before { Agency.find_or_create_by!(code: 'actiale', label: 'Actiale') }

  # Création des acteurs
  let(:fve) { create(:user, :fve, agency: 'actiale') }
  let(:merch) { create(:user, role: :merch) }

  # Contrat nécessaire pour établir le lien FVE/Merch dans la base de données
  let(:contract) { create(:contract, user: merch, fve: fve, agency: 'actiale') }

  # Authentification de l'utilisateur FVE
  before do
    sign_in fve, scope: :user
    # On force l'initialisation du contrat pour s'assurer qu'il existe
    contract
  end

  describe "GET /show (Planning d'un Merch)" do
    it "affiche la page ou redirige si la ressource est trouvée (200 ou 302)" do
      get fve_planning_path(merch)
      expect(response.status).to be_in([200, 302])
    end
  end
end
