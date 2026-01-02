class ContactsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:new, :create]

  def new
    @contact = Contact.new
    render 'static_pages/contact'
  end

  def create
    @contact = Contact.new(contact_params)

    if @contact.valid?
      ContactMailer.new_contact(@contact).deliver_now
      redirect_to new_contact_path, notice: "Message envoyé avec succès ! On vous répond vite."
    else
      render 'static_pages/contact', status: :unprocessable_entity
    end
  end

  private

  def contact_params
    params.require(:contact).permit(:name, :email, :message)
  end
end
