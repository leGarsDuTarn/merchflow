class ChangeHourlyRateDefaultInContracts < ActiveRecord::Migration[8.1]
  def change
    change_column :contracts, :hourly_rate, :decimal,
                  precision: 5, scale: 2,
                  null: false, default: 11.88
  end
end
