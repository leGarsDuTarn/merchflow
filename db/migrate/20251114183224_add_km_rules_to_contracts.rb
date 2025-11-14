class AddKmRulesToContracts < ActiveRecord::Migration[8.1]
  def change
    add_column :contracts, :km_limit, :decimal,
               precision: 5, scale: 2,
               null: false, default: 0.0

    add_column :contracts, :km_unlimited, :boolean,
               null: false, default: false
  end
end
