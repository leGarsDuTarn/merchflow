class RemoveHourlyRateFromContracts < ActiveRecord::Migration[8.1]
  def change
    remove_column :contracts, :hourly_rate
  end
end
