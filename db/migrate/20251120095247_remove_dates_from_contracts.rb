class RemoveDatesFromContracts < ActiveRecord::Migration[8.1]
  def change
    remove_column :contracts, :start_date, :date
    remove_column :contracts, :end_date, :date
  end
end
