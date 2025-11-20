class RemoveMealFieldsFromWorkSessions < ActiveRecord::Migration[8.1]
  def change
    remove_column :work_sessions, :meal_allowance, :decimal
    remove_column :work_sessions, :meal_eligible, :boolean
    remove_column :work_sessions, :meal_hours_required, :integer
  end
end

