class AddBreakTimesToWorkSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :work_sessions, :break_start_time, :datetime
    add_column :work_sessions, :break_end_time, :datetime
  end
end
