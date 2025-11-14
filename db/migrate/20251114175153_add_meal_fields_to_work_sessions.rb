# Migration: Add meal allowance system to work sessions
class AddMealFieldsToWorkSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :work_sessions, :meal_eligible, :boolean,
               null: false, default: false

    add_column :work_sessions, :meal_allowance, :decimal,
               precision: 5, scale: 2,
               null: false, default: 0.0

    add_column :work_sessions, :meal_hours_required, :integer,
               null: false, default: 5
  end
end
