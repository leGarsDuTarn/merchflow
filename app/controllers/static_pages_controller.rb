class StaticPagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:privacy, :contact, :legal_notices, :terms, :community]

  def privacy
    # Le contenu est rendu directement par la vue
  end

  def contact
    @contact = Contact.new
  end

  def legal_notices
    # Le contenu est rendu directement par la vue
  end

  def terms
    # Le contenu est rendu directement par la vue
  end

  def community
  # Le contenu est rendu directement par la vue
  end
end
