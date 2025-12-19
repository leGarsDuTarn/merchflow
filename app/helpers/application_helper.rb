module ApplicationHelper
  include Pagy::Frontend

  def inline_error_for(resource, field)
    # 1. Cas classique : erreurs de validation (Inscription, Profil, etc.)
    if resource.errors[field].present?
      return content_tag(:div, resource.errors[field].first,
                         class: "text-flash-orange small mt-1")
    end

    # 2. Cas particulier : Erreur de Login Devise (Flash alert)
    # Si on est sur le champ email et qu'une alerte existe, on l'affiche ici.
    if field == :email && controller_name == 'sessions' && flash[:alert].present?
      return content_tag(:div, "Email ou mot de passe incorrect.",
                         class: "text-flash-orange small mt-1")
    end

    nil
  end
end
