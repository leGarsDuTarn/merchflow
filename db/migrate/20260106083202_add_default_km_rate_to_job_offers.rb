class AddDefaultKmRateToJobOffers < ActiveRecord::Migration[8.1]
  def change
    change_column_default :job_offers, :km_rate, from: nil, to: 0.29
  end
end
