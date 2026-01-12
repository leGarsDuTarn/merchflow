class JobOfferSlot < ApplicationRecord
  belongs_to :job_offer
  validates :date, :start_time, :end_time, presence: true

  validate :end_time_after_start_time
  validate :break_times_consistency

  private

  # app/models/job_offer_slot.rb

  def end_time_after_start_time
    return if end_time.blank? || start_time.blank?

    # On utilise le message exact attendu par le test
    if end_time.strftime("%H:%M") == start_time.strftime("%H:%M")
      errors.add(:end_time, "doit être strictement après l'heure de début")
    end

    # Si tu ne veux PAS autoriser les missions qui passent minuit sans flag spécifique :
    if end_time.strftime("%H:%M") < start_time.strftime("%H:%M")
       # Si ton métier n'autorise pas le passage à minuit sur un seul slot :
       errors.add(:end_time, "doit être après l'heure de début")
    end
  end

  def break_times_consistency
    if break_start_time.present? ^ break_end_time.present?
      errors.add(:base, "Pour la pause, le début et la fin sont requis")
      return
    end
    return if break_start_time.blank?

    # Normalisation pour comparaison
    m_start = start_time.strftime("%H:%M")
    m_end   = end_time.strftime("%H:%M")
    b_start = break_start_time.strftime("%H:%M")
    b_end   = break_end_time.strftime("%H:%M")

    # 1. La fin de pause doit être après le début de la pause
    if b_end <= b_start
      errors.add(:break_end_time, "doit être après le début de la pause")
    end

    # 2. La pause doit être comprise dans les horaires de mission
    # On ne valide le "dedans" que si la mission ne passe pas par minuit
    if m_start < m_end
      if b_start < m_start || b_end > m_end
        errors.add(:break_start_time, "la pause doit être comprise dans les horaires de mission")
      end
    end
  end
end
