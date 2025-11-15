class AddEffectiveKmToWorkSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :work_sessions, :effective_km, :decimal,
               precision: 5, scale: 2,
               null: false, default: 0.0
  end
end
