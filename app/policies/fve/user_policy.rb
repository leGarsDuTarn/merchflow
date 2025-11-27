class Fve::UserPolicy < ApplicationPolicy

  def show?
    user&.fve? || user&.admin?
  end

  def index?
    user&.fve? || user&.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.merch
    end
  end
end
