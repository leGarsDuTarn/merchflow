module Fve
  class JobApplicationPolicy < ApplicationPolicy
    def destroy?
      # L'utilisateur doit être un FVE
      # ET il doit être le créateur de l'offre liée à cette candidature
      user.fve? && record.job_offer.fve_id == user.id
    end

    class Scope < Scope
      def resolve
        scope.all
      end
    end
  end
end
