class UpdateExistingRatesToBase100 < ActiveRecord::Migration[8.1]
  def up
    puts "--- Début de la mise à jour des données ---"

    say_with_time "Conversion des taux IFM/CP (Base 0.1 -> Base 100)" do
      # On compte combien de contrats vont être modifiés pour le log
      count = Contract.where(ifm_rate: [0.1, 0, nil]).count

      if count > 0
        puts "   -> #{count} contrat(s) détecté(s) avec d'anciens taux."

        # Mise à jour massive
        Contract.where(ifm_rate: [0.1, 0, nil]).update_all(ifm_rate: 10.0)
        Contract.where(cp_rate: [0.1, 0, nil]).update_all(cp_rate: 10.0)

        puts "   -> Mise à jour réussie : 10.0% appliqué."
      else
        puts "   -> Aucun contrat à mettre à jour."
      end
    end

    puts "--- Migration terminée avec succès ---"
  end

  def down
    puts "--- Rétropédalage des données ---"
    Contract.where(ifm_rate: 10.0).update_all(ifm_rate: 0.1)
    Contract.where(cp_rate: 10.0).update_all(cp_rate: 0.1)
    puts "--- Les taux sont revenus à 0.1 ---"
  end
end
