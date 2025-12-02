class AddFveIdAndMerchIdToContracts < ActiveRecord::Migration[8.1]
  def change
    add_column :contracts, :fve_id, :integer
    add_column :contracts, :merch_id, :integer

    add_index :contracts, :fve_id
    add_index :contracts, :merch_id
    add_index :contracts, %i[fve_id merch_id], unique: true
  end
end
