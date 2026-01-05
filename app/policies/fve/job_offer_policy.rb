# app/policies/fve/job_offer_policy.rb
module Fve
  class JobOfferPolicy < ApplicationPolicy
    def index?
      user.fve?
    end

    def show?
      user.fve? && (record.fve_id == user.id || user.admin?)
    end

    def create?
      user.fve?
    end

    def update?
      show?
    end

    def destroy?
      show?
    end

    def accept_candidate?
      show?
    end

    class Scope < Scope
      def resolve
        if user.admin?
          scope.all
        else
          scope.where(fve_id: user.id)
        end
      end
    end
  end
end
