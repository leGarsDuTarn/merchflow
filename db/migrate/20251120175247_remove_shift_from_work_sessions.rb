class RemoveShiftFromWorkSessions < ActiveRecord::Migration[8.1]
  def change
    remove_column :work_sessions, :shift, :string
  end
end
