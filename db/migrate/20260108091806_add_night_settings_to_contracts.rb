class AddNightSettingsToContracts < ActiveRecord::Migration[8.1]
  def change
    
    add_column :contracts, :night_start, :integer, default: 21
    add_column :contracts, :night_end, :integer, default: 6

    change_column_default :contracts, :night_rate, from: 0.5, to: 50.0
  end
end
