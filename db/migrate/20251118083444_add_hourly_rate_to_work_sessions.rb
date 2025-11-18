class AddHourlyRateToWorkSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :work_sessions, :hourly_rate, :decimal, precision: 5, scale: 2, default: 11.88, null: false
  end
end
