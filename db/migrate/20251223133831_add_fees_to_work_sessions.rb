class AddFeesToWorkSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :work_sessions, :fee_parking, :decimal, precision: 10, scale: 2, default: 0.0
    add_column :work_sessions, :fee_toll, :decimal, precision: 10, scale: 2, default: 0.0
    add_column :work_sessions, :fee_meal, :decimal, precision: 10, scale: 2, default: 0.0
  end
end
