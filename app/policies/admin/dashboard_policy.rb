class Admin::DashboardPolicy < ApplicationPolicy
  def index?
    user&.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.none
    end
  end
end
