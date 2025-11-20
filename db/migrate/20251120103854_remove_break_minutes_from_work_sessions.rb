class RemoveBreakMinutesFromWorkSessions < ActiveRecord::Migration[8.1]
  def change
    remove_column :work_sessions, :break_minutes, :integer
  end
end
