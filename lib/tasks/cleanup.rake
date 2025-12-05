# lib/tasks/cleanup.rake

namespace :cleanup do
  desc "Supprime définitivement les MissionProposals qui sont expirées (passées en date et heure)."
  task old_proposals: :environment do
    puts "--- Démarrage du nettoyage des MissionProposals expirées..."

    # Définition de la condition pour être considéré comme "expiré"
    # C'est l'inverse exact de la logique utilisée dans le scope :active_opportunities
    expired_condition = "
      (date < CURRENT_DATE)
      OR
      (
        date = CURRENT_DATE AND
        (date::timestamp + start_time::time::interval) <= (NOW() AT TIME ZONE 'Europe/Paris')::timestamp
      )
    "

    # Exécuter la recherche et la suppression
    expired_proposals = MissionProposal.where(expired_condition)

    count = expired_proposals.count

    # Utilisez .delete_all pour une suppression plus rapide
    # .delete_all ne déclenche pas les callbacks ActiveRecord.
    expired_proposals.delete_all

    puts "--- #{count} MissionProposals expirées ont été supprimées définitivement de la base de données."
  end
end
