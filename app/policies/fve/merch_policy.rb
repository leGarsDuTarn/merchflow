# app/policies/fve/merch_policy.rb
class Fve::MerchPolicy < ApplicationPolicy
  def index?
    user&.fve? || user&.admin?
  end

  def show?
    user&.fve? || user&.admin?
  end

  # Même qulqu'un essaie d'appeler l'URL /toggle_favorite manuellement,
  # Pundit le bloquera si pas Premium.
  def toggle_favorite?
    user&.premium? || user&.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(role: :merch)
    end
  end
end
