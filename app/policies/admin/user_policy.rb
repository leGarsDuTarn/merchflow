class Admin::UserPolicy < ApplicationPolicy

  # ==============
  # AUTORISATIONS
  # ==============

  def index?
    admin?
  end

  def show?
    admin?
  end

  def create?
    admin?
  end

  def new?
    create?
  end

  def update?
    admin?
  end

  def edit?
    update?
  end

  def destroy?
    admin?
  end

  def toggle_premium?
    admin?
  end

  # ==============
  # SCOPE
  # ==============
  class Scope < ApplicationPolicy::Scope
    def resolve
      # Un admin peut voir tous les utilisateurs
      scope.all
    end
  end

  private

  def admin?
    user&.admin?
  end
end
