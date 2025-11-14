class CreateWorkSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :work_sessions do |t|
      t.references :contract, null: false, foreign_key: true

      t.date     :date, null: false
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false

      t.integer :break_minutes,    null: false, default: 0
      t.integer :duration_minutes, null: false, default: 0
      t.integer :night_minutes,    null: false, default: 0

      t.string :store, null: false, default: "Unknown"

      t.string :shift, null: false, default: "unknown"

      t.text :notes

      t.timestamps
    end

    add_index :work_sessions, :date
    add_index :work_sessions, :shift
  end
end
