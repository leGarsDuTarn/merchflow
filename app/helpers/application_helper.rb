module ApplicationHelper
  include Pagy::Frontend

  # --- Tes helpers existants ---
  def inline_error_for(resource, field)
    # ... (ton code existant inchangé)
  end

  # --- Nouveaux helpers stylisés MerchFlow ---

  def job_status_badge(status)
    case status
    when 'pending'
      content_tag(:span, "En attente", class: "badge bg-orange-light text-orange border border-orange-subtle rounded-pill px-2 py-1 small fw-normal")
    when 'accepted'
      content_tag(:span, "Acceptée", class: "badge bg-success bg-opacity-10 text-success border border-success rounded-pill px-2 py-1 small fw-normal")
    when 'rejected', 'archived'
      content_tag(:span, "Refusée", class: "badge bg-danger bg-opacity-10 text-danger border border-danger rounded-pill px-2 py-1 small fw-normal")
    else
      content_tag(:span, status.capitalize, class: "badge bg-secondary bg-opacity-10 text-secondary border rounded-pill px-2 py-1 small fw-normal")
    end
  end

  def job_status_color(status)
    case status
    when 'pending'  then '#fd7e14' # Ton Orange MerchFlow
    when 'accepted' then '#198754' # Vert succès
    when 'rejected' then '#dc3545' # Rouge danger
    else '#6c757d'                 # Gris technique
    end
  end

  # Helper pour la classe de fond des cartes (utilisé dans ta vue show)
  def job_status_card_class(status)
    case status
    when 'accepted' then 'border-success bg-success bg-opacity-10'
    when 'rejected' then 'border-danger bg-danger bg-opacity-10'
    else 'border-light bg-light'
    end
  end
end
