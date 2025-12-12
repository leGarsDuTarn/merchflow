# spec/policies/admin/user_policy_spec.rb

require 'rails_helper'

RSpec.describe Admin::UserPolicy, type: :policy do

  before do
    Agency.find_or_create_by!(code: 'actiale', label: 'Actiale')
  end

  # --- PRÉREQUIS ---
  let(:admin_user) { create(:user, :admin) }
  # Le FVE user va maintenant réussir à se créer car l'agence 'actiale' existe
  let(:fve_user)   { create(:user, :fve, agency: 'actiale') }
  let(:merch_user) { create(:user, :merch) }

  let(:target_user) { create(:user, :merch) }
  let(:all_users) { User.all }

  # ------------------------------------------------------------
  # 1. TEST DU SCOPE
  # ------------------------------------------------------------
  permissions ".scope" do
    it 'autorise l\'Admin à voir tous les utilisateurs' do
      scope = Admin::UserPolicy::Scope.new(admin_user, User).resolve
      expect(scope).to match_array(all_users)
    end
  end

  # ------------------------------------------------------------
  # 2. TEST DES PERMISSIONS (CRUD)
  # ------------------------------------------------------------
  permissions :index?, :show?, :create?, :update?, :toggle_premium?, :export_data? do

    it 'autorise l\'Admin' do
      expect(described_class).to permit(admin_user, target_user)
    end

    it 'interdit le Merch' do
      expect(described_class).not_to permit(merch_user, target_user)
    end

    it 'interdit le FVE' do
      expect(described_class).not_to permit(fve_user, target_user)
    end
  end

  # ------------------------------------------------------------
  # 3. TEST DESTROY
  # ------------------------------------------------------------
  permissions :destroy? do

    it 'autorise l\'Admin à détruire un autre utilisateur' do
      expect(described_class).to permit(admin_user, target_user)
    end

    it 'interdit à l\'Admin de se détruire lui-même' do
      expect(described_class).not_to permit(admin_user, admin_user)
    end

    it 'interdit aux non-admins de détruire' do
      expect(described_class).not_to permit(merch_user, target_user)
    end
  end
end
