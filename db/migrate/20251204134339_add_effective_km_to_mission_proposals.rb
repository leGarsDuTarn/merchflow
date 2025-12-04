class AddEffectiveKmToMissionProposals < ActiveRecord::Migration[8.1]
  def change
    add_column :mission_proposals, :effective_km, :decimal, precision: 5, scale: 2
  end
end
