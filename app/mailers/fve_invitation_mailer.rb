class FveInvitationMailer < ApplicationMailer
  # Optionnel : si tu as une adresse d'envoi spécifique
  default from: 'grassiano.b@gmail.com'

  # MODIFICATION : Accepte deux arguments (l'invitation ET le label)
  def invite_fve(invitation, agency_label)
    @invitation = invitation
    @agency_label = agency_label # <-- Nouvelle variable d'instance pour le template

    # L'ancienne ligne @agency_label = Contract::AGENCY_LABELS[...] EST SUPPRIMÉE

    # Génération du lien unique
    # Rails saura utiliser localhost:3000 ou le domaine de prod selon la config
    @url = fve_accept_invitation_url(token: @invitation.token)

    mail(
      to: @invitation.email,
      subject: "Invitation à rejoindre l'application Merchflow (#{@agency_label})"
    )
  end
end
