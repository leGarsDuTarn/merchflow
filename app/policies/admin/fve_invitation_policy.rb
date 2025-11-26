class Admin::FveInvitationPolicy < ApplicationPolicy

  # Uniquement les admins ont accès
  def index?
    admin?
  end

  def new?
    admin?
  end

  def create?
    admin?
  end

  def destroy?
    admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end

  private

  def admin?
    user&.admin?
  end
end
