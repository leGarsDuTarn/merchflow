class AddNightRateToJobOffers < ActiveRecord::Migration[8.1]
  def change
    # taux de majoration nuit (ex: 0.50 pour 50%, 0.35 pour 35%)
    # 0.50 par défaut (standard classique), mais l'agence pourra le changer
    add_column :job_offers, :night_rate, :decimal, precision: 4, scale: 2, default: 0.50, null: false
  end
end
