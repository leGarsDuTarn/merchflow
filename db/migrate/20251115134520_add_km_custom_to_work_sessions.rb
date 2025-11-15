class AddKmCustomToWorkSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :work_sessions, :km_custom, :decimal, precision: 5, scale: 2
  end
end
