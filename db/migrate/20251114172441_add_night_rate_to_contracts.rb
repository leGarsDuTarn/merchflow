# Migration: adds night_rate (night shift bonus) to contracts
class AddNightRateToContracts < ActiveRecord::Migration[8.1]
  def change
    add_column :contracts, :night_rate, :decimal,
               precision: 4, scale: 2,
               null: false, default: 0.35
  end
end
