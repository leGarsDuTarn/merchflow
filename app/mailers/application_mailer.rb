class ApplicationMailer < ActionMailer::Base
  # On utilise l'adresse officielle validée chez Mailjet
  default from: "contact@merchflow.fr"
  layout "mailer"
end
