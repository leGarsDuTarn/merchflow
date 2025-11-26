class Fve::DashboardPolicy < ApplicationPolicy
  def index?
    user&.fve?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.none
    end
  end
end
