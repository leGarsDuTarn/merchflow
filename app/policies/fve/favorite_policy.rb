class Fve::FavoritePolicy < ApplicationPolicy
  def create?
    # SÉCURITÉ : Seuls les Premium (ou Admin) peuvent gérer leur équipe
    user.premium? || user.admin?
  end

  def destroy?
    create?
  end
end
