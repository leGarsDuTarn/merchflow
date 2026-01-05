module ApplicationHelper
  include Pagy::Frontend

  # --- Tes helpers existants ---
  def inline_error_for(resource, field)
    if resource.errors[field].present?
      return content_tag(:div, resource.errors[field].first,
                         class: "text-flash-orange small mt-1")
    end

    if field == :email && controller_name == 'sessions' && flash[:alert].present?
      return content_tag(:div, "Email ou mot de passe incorrect.",
                         class: "text-flash-orange small mt-1")
    end
    nil
  end

  # --- Nouveaux helpers pour les Candidatures ---

  def job_status_badge(status)
    case status
    when 'pending'
      content_tag(:span, "En attente", class: "badge rounded-pill bg-warning text-dark px-3 shadow-sm")
    when 'accepted'
      content_tag(:span, "Acceptée", class: "badge rounded-pill bg-success px-3 shadow-sm")
    when 'refused'
      content_tag(:span, "Refusée", class: "badge rounded-pill bg-danger px-3 shadow-sm")
    else
      content_tag(:span, status.capitalize, class: "badge rounded-pill bg-secondary px-3 shadow-sm")
    end
  end

  def job_status_color(status)
    case status
    when 'pending'  then '#ffc107' # Jaune Bootstrap
    when 'accepted' then '#198754' # Vert Bootstrap
    when 'refused'  then '#dc3545' # Rouge Bootstrap
    else '#6c757d'                 # Gris
    end
  end
end
