class Fve::PlanningsPolicy < ApplicationPolicy
  def show?
    user&.fve? || user&.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.none
    end
  end
end
