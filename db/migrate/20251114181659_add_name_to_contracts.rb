class AddNameToContracts < ActiveRecord::Migration[8.1]
  def change
    add_column :contracts, :name, :string, null: false, default: ""
  end
end
