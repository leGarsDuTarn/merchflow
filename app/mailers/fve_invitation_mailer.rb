class FveInvitationMailer < ApplicationMailer
  # Optionnel : si tu as une adresse d'envoi spécifique
  default from: 'grassiano.b@gmail.com'

  def invite_fve(invitation)
    @invitation = invitation

    # Récupération du "Joli Nom" de l'agence pour l'afficher dans le mail
    @agency_label = Contract::AGENCY_LABELS[@invitation.agency] || @invitation.agency.humanize

    # Génération du lien unique
    # Rails saura utiliser localhost:3000 ou le domaine de prod selon la config
    @url = fve_accept_invitation_url(token: @invitation.token)

    mail(
      to: @invitation.email,
      subject: "Invitation à rejoindre l'application Merchflow (#{@agency_label})"
    )
  end
end
