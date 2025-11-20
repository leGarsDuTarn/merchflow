class RemoveAnnexFieldsFromContracts < ActiveRecord::Migration[8.1]
  def change
    remove_column :contracts, :annex_minutes_per_hour, :integer
    remove_column :contracts, :annex_extra_minutes, :integer
    remove_column :contracts, :annex_threshold_hours, :decimal
  end
end
