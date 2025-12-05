# config/schedule.rb

# Optionnel : Définit le chemin du fichier de log pour le Cron
set :output, "log/cron.log"
# Optionnel : Définit l'environnement pour lequel la tâche est générée
# set :environment, 'production'


every 1.day, at: '3:00 am' do
  # Exécute la tâche Rake pour supprimer les MissionProposals expirées
  rake "cleanup:old_proposals"
end
