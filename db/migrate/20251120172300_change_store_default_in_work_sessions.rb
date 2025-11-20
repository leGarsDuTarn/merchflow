class ChangeStoreDefaultInWorkSessions < ActiveRecord::Migration[8.1]
  def change
    change_column_default :work_sessions, :store, nil
    change_column_null :work_sessions, :store, true
  end
end
