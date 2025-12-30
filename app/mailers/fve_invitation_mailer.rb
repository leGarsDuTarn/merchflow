class FveInvitationMailer < ApplicationMailer
  # SUPPRIME la ligne 'default from' ici.
  # Le mail partira automatiquement avec "contact@merchflow.fr" grâce à ApplicationMailer.

  # Accepte deux arguments (l'invitation ET le label)
  def invite_fve(invitation, agency_label)
    @invitation = invitation
    @agency_label = agency_label

    # Génération du lien unique
    @url = fve_accept_invitation_url(token: @invitation.token)

    mail(
      to: @invitation.email,
      subject: "Invitation à rejoindre l'application Merchflow (#{@agency_label})"
    )
  end
end
