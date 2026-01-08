class ChangeNightRateDefaultInJobOffers < ActiveRecord::Migration[8.1]
  def change
    change_column_default :job_offers, :night_rate, from: 0.5, to: 50.0
  end
end
