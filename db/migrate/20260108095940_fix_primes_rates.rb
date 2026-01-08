class FixPrimesRates < ActiveRecord::Migration[8.1]
  def up
    # 1. On met à jour les données existantes
    # On cherche tout ce qui est petit (0.1) et on le multiplie par 100
    # update_all est ultra rapide et ne déclenche pas de validations bloquantes
    Contract.where("ifm_rate < 1").update_all("ifm_rate = ifm_rate * 100")
    Contract.where("cp_rate < 1").update_all("cp_rate = cp_rate * 100")

    # 2. On change les valeurs par défaut pour l'avenir
    # Désormais, un nouveau contrat aura 10.0 (10%) et non plus 0.1
    change_column_default :contracts, :ifm_rate, from: 0.1, to: 10.0
    change_column_default :contracts, :cp_rate, from: 0.1, to: 10.0

    puts "✅ IFM et CP convertis en base 100 (ex: 10.0%)"
  end

  def down
    # Retour arrière en cas de panique
    change_column_default :contracts, :ifm_rate, from: 10.0, to: 0.1
    change_column_default :contracts, :cp_rate, from: 10.0, to: 0.1

    Contract.where("ifm_rate >= 1").update_all("ifm_rate = ifm_rate / 100.0")
    Contract.where("cp_rate >= 1").update_all("cp_rate = cp_rate / 100.0")
  end
end
