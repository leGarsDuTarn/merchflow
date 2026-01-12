class JobOfferSlot < ApplicationRecord
  belongs_to :job_offer

  validates :date, :start_time, :end_time, presence: true
  validate :end_time_different_from_start_time
  validate :break_times_consistency

  private

  def end_time_different_from_start_time
    return if end_time.blank? || start_time.blank?

    # On refuse UNIQUEMENT si c'est la même heure exacte (durée 0)
    if end_time.strftime("%H:%M") == start_time.strftime("%H:%M")
      errors.add(:end_time, "doit être strictement après l'heure de début")
    end
  end

  def break_times_consistency
    if break_start_time.present? ^ break_end_time.present?
      errors.add(:base, "Pour la pause, le début et la fin sont requis")
      return
    end

    return if break_start_time.blank?

    b_start = break_start_time.strftime("%H:%M")
    b_end   = break_end_time.strftime("%H:%M")
    m_start = start_time.strftime("%H:%M")
    m_end   = end_time.strftime("%H:%M")

    # 1. La fin de pause doit être après le début de la pause (Strictement)
    # Contrairement à la mission, une pause ne passe JAMAIS minuit
    if b_end <= b_start
      errors.add(:break_end_time, "doit être après le début de la pause")
    end

    # 2. La pause doit être comprise dans les horaires de mission
    # On ne vérifie que pour les missions classiques (ne passant pas minuit)
    if m_start < m_end
      if b_start < m_start || b_end > m_end
        errors.add(:break_start_time, "la pause doit être comprise dans les horaires de mission")
      end
    end
  end
end
