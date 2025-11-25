module ApplicationHelper
  include Pagy::Frontend

  # Permet de mettre une erreur inline sous chaque champ d'un formulaire mal ou pas rensigné
  def inline_error_for(resource, field)
    return unless resource.errors[field].present?

    content_tag(:div, resource.errors[field].first,
                class: "text-flash-orange small mt-1")
  end
end
