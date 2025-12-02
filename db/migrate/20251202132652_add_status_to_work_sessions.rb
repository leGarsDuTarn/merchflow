class AddStatusToWorkSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :work_sessions, :status, :integer, default: 0 # 0 = pending
  end
end
