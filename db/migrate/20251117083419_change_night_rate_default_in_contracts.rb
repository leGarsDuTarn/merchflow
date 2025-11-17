class ChangeNightRateDefaultInContracts < ActiveRecord::Migration[8.1]
  def change
    change_column_default :contracts, :night_rate, 0.5
  end
end

