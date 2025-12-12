require 'rails_helper'

RSpec.describe "Fve::Dashboards", type: :request do
  # 1. Création d'une Agence car un FVE doit en avoir une (validation User)
  before { Agency.find_or_create_by!(code: 'actiale', label: 'Actiale') }

  # 2. Création d'un utilisateur FVE
  let(:fve) { create(:user, :fve, agency: 'actiale') }

  before do
    sign_in fve, scope: :user
  end

  describe "GET /index" do
    it "returns http success" do
      get "/fve/dashboard"
      expect(response).to have_http_status(:success)
    end
  end
end
