class Fve::InvitationsPolicy < ApplicationPolicy
  def accept?
    true
  end

  def complete?
    true
  end

  def index?
    user&.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.none
    end
  end
end
