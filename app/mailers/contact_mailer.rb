class ContactMailer < ApplicationMailer

  def new_contact(contact)
    @contact = contact

    mail(
      to: "contact@merchflow.fr", # Ton adresse de réception officielle
      reply_to: @contact.email,
      subject: "📩 Nouveau message de contact : #{@contact.name}"
    )
  end
end
