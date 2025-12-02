# app/controllers/fve/invitations_controller.rb
module Fve
  class InvitationsController < ApplicationController
    # NOTE: L'inclusion de Pundit::Authorization n'est pas nécessaire si Pundit est inclus
    # globalement dans ApplicationController, mais nous le conservons ici par précaution.
    include Pundit::Authorization

    before_action :set_invitation, only: %i[accept complete]

    def accept
      # Vérification de l'autorisation Pundit
      authorize %i[fve invitations], :accept?

      if @invitation.used?
        # Utiliser `flash` directement au lieu de `redirect_to` pour une erreur
        # si l'invitation a déjà été utilisée (bien que le redirect fonctionne).
        redirect_to root_path, alert: 'Cette invitation a déjà été utilisée.'
        return
      end

      if @invitation.expired?
        redirect_to root_path, alert: 'Cette invitation a expiré.'
        return
      end

      # On pré-remplit l'email pour le confort de l'utilisateur
      @user = User.new(email: @invitation.email)
    end

    def complete
      # Vérification de l'autorisation Pundit
      authorize %i[fve invitations], :complete?

      # Double vérification avant de créer l'utilisateur (sécurité)
      if @invitation.used? || @invitation.expired?
         redirect_to root_path, alert: 'L\'invitation est invalide ou a expiré.'
         return
      end


      @user = User.new(user_params)
      # Assignation des rôles et attributs basés sur l'invitation
      @user.role    = :fve
      @user.premium = @invitation.premium
      @user.agency  = @invitation.agency

      if @user.save
        # CRITIQUE : Marquer l'invitation comme utilisée
        @invitation.update(used: true)

        # Connecter l'utilisateur immédiatement (Devise)
        sign_in(@user)

        # Rediriger vers le dashboard FVE
        redirect_to fve_dashboard_path,
                    notice: 'Votre compte FVE est maintenant actif. Bienvenue !'
      else
        # En cas d'échec de validation (ex: mot de passe trop faible)
        # Rendre la vue :accept pour afficher les erreurs sur le formulaire
        render :accept, status: :unprocessable_entity
      end
    end

    private

    # Assure que l'invitation existe et gère la redirection si elle n'est pas trouvée
    def set_invitation
      @invitation = FveInvitation.find_by(token: params[:token])

      unless @invitation
        redirect_to root_path, alert: 'Invitation introuvable.'
        # NOTE : Il est crucial d'utiliser `return` ou `head` après un redirect_to
        # dans un before_action pour stopper l'exécution du reste de la chaîne.
        return
      end
    end

    def user_params
      # Assurez-vous que le formulaire de la vue :accept envoie bien :email,
      # même s'il est pré-rempli.
      params.require(:user).permit(
        :email,
        :password,
        :password_confirmation,
        :firstname,
        :lastname,
        :username # L'username est requis par le modèle User (sauf si FVE)
      )
      # NOTE : J'ai ajouté :username ici, car si vous avez une validation
      # de présence sur username dans le modèle User (sauf si fve?),
      # il doit être transmis par le formulaire.
    end
  end
end
