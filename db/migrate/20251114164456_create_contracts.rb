class CreateContracts < ActiveRecord::Migration[8.1]
  def change
    create_table :contracts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :agency, null: false, default: 'other'
      t.string :location
      t.decimal :hourly_rate, precision: 5, scale: 2
      t.decimal :km_rate, precision: 5, scale: 2
      t.date :start_date
      t.date :end_date
      t.string :contract_type
      t.text :notes

      t.timestamps
    end
  end
end
