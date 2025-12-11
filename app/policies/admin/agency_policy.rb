class Admin::AgencyPolicy < ApplicationPolicy
  # ==============
  # AUTORISATIONS
  # ==============

  def index?
    admin?
  end

  def show?
    admin?
  end

  def new?
    admin?
  end

  def create?
    admin?
  end

  def edit?
    admin?
  end

  def update?
    admin?
  end

  def destroy?
    admin?
  end

  # ==============
  # SCOPE
  # ==============
  class Scope < ApplicationPolicy::Scope
    def resolve
      # Un admin peut voir toutes les agences
      scope.all
    end
  end

  private

  def admin?
    user&.admin?
  end
end
