class Fve::MerchPolicy < ApplicationPolicy
  def index?
    user&.fve? || user&.admin?
  end

  def show?
    user&.fve? || user&.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(role: :merch)
    end
  end
end
