module Fve
  class InvitationsController < ApplicationController
    # On n'a PAS besoin de 'authenticate_user!' ici car l'utilisateur n'existe pas encore.
    # On inclut Pundit si ce n'est pas fait dans ApplicationController

    before_action :set_invitation, only: %i[accept complete]

    def accept
      # Autorisation publique (défini à true dans la Policy)
      authorize %i[fve invitations], :accept?

      if @invitation.used?
        redirect_to root_path, alert: 'Cette invitation a déjà été utilisée.'
        return
      end

      if @invitation.expired?
        redirect_to root_path, alert: 'Cette invitation a expiré.'
        return
      end

      @user = User.new(email: @invitation.email)

      # Récupération du label pour l'affichage
      set_agency_label
    end

    def complete
      authorize %i[fve invitations], :complete?

      if @invitation.used? || @invitation.expired?
         redirect_to root_path, alert: 'L\'invitation est invalide ou a expiré.'
         return
      end

      @user = User.new(user_params)

      # SÉCURITÉ : On force l'email et l'agence venant de l'invitation
      # On ignore ce que le formulaire tente d'envoyer pour ces champs.
      @user.email   = @invitation.email
      @user.agency  = @invitation.agency
      @user.premium = @invitation.premium
      @user.role    = :fve

      if @user.save
        # Marquer l'invitation comme utilisée
        @invitation.update!(used: true)

        # Connecter l'utilisateur
        sign_in(@user)

        redirect_to fve_dashboard_path,
                    notice: 'Votre compte FVE est maintenant actif. Bienvenue !'
      else
        # En cas d'erreur, on doit recharger le label pour la vue
        set_agency_label
        render :accept, status: :unprocessable_entity
      end
    end

    private

    def set_invitation
      @invitation = FveInvitation.find_by(token: params[:token])

      unless @invitation
        redirect_to root_path, alert: 'Invitation introuvable.'
        # return est nécessaire pour stopper l'exécution si appelé manuellement,
        # mais le redirect_to dans un before_action suffit généralement à stopper la chaîne Rails.
      end
    end

    # Méthode helper pour éviter la duplication de code entre accept et complete (en cas d'erreur)
    def set_agency_label
      @agency_label = Agency.find_by(code: @invitation.agency)&.label || @invitation.agency.to_s.humanize
    end

    def user_params
      # On retire :email des params permis car on l'impose via l'invitation
      params.require(:user).permit(
        :password,
        :password_confirmation,
        :firstname,
        :lastname,
        :username,
        :phone_number # Souvent utile à l'inscription
      )
    end
  end
end
