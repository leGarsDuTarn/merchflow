class RemoveEstimatedKmFromMissionProposals < ActiveRecord::Migration[8.1]
  def change
    remove_column :mission_proposals, :estimated_km, :integer
  end
end
