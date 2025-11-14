# Migration: Add annex time settings to contracts
class AddAnnexTimesToContracts < ActiveRecord::Migration[8.1]
  def change
    add_column :contracts, :annex_minutes_per_hour, :integer,
               null: false, default: 0

    add_column :contracts, :annex_extra_minutes, :integer,
               null: false, default: 0

    add_column :contracts, :annex_threshold_hours, :decimal,
               precision: 4, scale: 2,
               null: false, default: 0.0
  end
end
