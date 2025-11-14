class CreateKilometerLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :kilometer_logs do |t|
      t.references :work_session, null: false, foreign_key: true

      t.decimal :km_rate, precision: 5, scale: 2, null: false, default: 0.29
      t.decimal :distance, precision: 5, scale: 2, null: false, default: 0.0

      t.string :description, default: ""
      t.timestamps
    end

    add_index :kilometer_logs, :distance
  end
end
