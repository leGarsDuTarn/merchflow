class FixOldContractRates < ActiveRecord::Migration[8.1]
  def up
    # On cherche tous les contrats qui ont un taux "ancien format" (inférieur à 1, ex: 0.5)
    # Et on les multiplie par 100 pour passer au "nouveau format" (ex: 50.0)

    Contract.where("night_rate < 1").find_each do |contract|
      # On utilise update_columns pour ne pas déclencher les validations/callbacks
      # et aller super vite
      new_rate = contract.night_rate * 100
      contract.update_columns(night_rate: new_rate)
    end

    puts "✅ Tous les anciens contrats ont été convertis (ex: 0.5 -> 50.0)"
  end

  def down
    # Si on doit annuler, on redivise par 100
    Contract.where("night_rate >= 1").find_each do |contract|
      contract.update_columns(night_rate: contract.night_rate / 100.0)
    end
  end
end
