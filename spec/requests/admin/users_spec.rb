require 'rails_helper'

RSpec.describe "Admin::Users", type: :request do
  let(:admin) { create(:user, role: :admin) }
  # On crée un user cible pour pouvoir tester show/edit
  let(:target_user) { create(:user) }

  before do
    sign_in admin, scope: :user
  end

  describe "GET /index" do
    it "returns http success" do
      get "/admin/users"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get "/admin/users/#{target_user.id}"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /edit" do
    it "returns http success" do
      get "/admin/users/#{target_user.id}/edit"
      expect(response).to have_http_status(:success)
    end
  end
end
