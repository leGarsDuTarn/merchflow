class JobOfferSlot < ApplicationRecord
  belongs_to :job_offer

  # Validations de présence
  validates :date, :start_time, :end_time, presence: true

  # Validations de cohérence
  validate :end_time_after_start_time
  validate :break_times_consistency

  private

  def end_time_after_start_time
    return if end_time.blank? || start_time.blank?

    # Permettre les missions qui passent minuit (ex: 22:00 → 02:00)
    # On refuse uniquement si les horaires sont strictement identiques
    if end_time.strftime("%H:%M") == start_time.strftime("%H:%M")
      errors.add(:end_time, "doit être strictement après l'heure de début")
    end
  end

  def break_times_consistency
    # Si l'un est présent, l'autre doit l'être aussi
    if break_start_time.present? ^ break_end_time.present?
      errors.add(:base, "Pour la pause, le début et la fin sont requis")
      return
    end

    return if break_start_time.blank?

    # 1. La fin de pause doit être après le début de la pause
    if break_end_time.strftime("%H:%M") <= break_start_time.strftime("%H:%M")
      errors.add(:break_end_time, "doit être après le début de la pause")
    end

    # 2. La pause doit être comprise dans les horaires de la mission
    # Pour les missions normales (non minuit), vérifier que la pause est dans les bornes
    # Pour les missions qui passent minuit, on skip cette validation car trop complexe
    m_start = start_time.strftime("%H:%M")
    m_end   = end_time.strftime("%H:%M")

    # Si la mission passe minuit (end < start), on ne valide pas la pause
    return if m_end <= m_start

    b_start = break_start_time.strftime("%H:%M")
    b_end   = break_end_time.strftime("%H:%M")

    if b_start < m_start || b_end > m_end
      errors.add(:break_start_time, "la pause doit être comprise dans les horaires de mission")
    end
  end
end
