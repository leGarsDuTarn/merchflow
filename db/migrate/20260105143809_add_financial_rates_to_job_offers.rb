class AddFinancialRatesToJobOffers < ActiveRecord::Migration[8.1]
  def change
    add_column :job_offers, :ifm_rate, :decimal, precision: 5, scale: 2, default: 10.0
    add_column :job_offers, :cp_rate, :decimal, precision: 5, scale: 2, default: 10.0
  end
end
