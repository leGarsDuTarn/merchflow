# Migration: Add IFM and CP rates to contracts
class AddIfmAndCpToContracts < ActiveRecord::Migration[8.1]
  def change
    add_column :contracts, :ifm_rate, :decimal,
               precision: 4, scale: 2,
               null: false, default: 0.10

    add_column :contracts, :cp_rate, :decimal,
               precision: 4, scale: 2,
               null: false, default: 0.10
  end
end
