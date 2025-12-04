class AddEstimatedKmToMissionProposals < ActiveRecord::Migration[8.1]
  def change
    add_column :mission_proposals, :estimated_km, :integer
  end
end
