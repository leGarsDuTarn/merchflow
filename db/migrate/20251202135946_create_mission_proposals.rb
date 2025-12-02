class CreateMissionProposals < ActiveRecord::Migration[8.1]
  def change
    create_table :mission_proposals do |t|
      # Qui propose à qui ?
      t.references :fve, null: false, foreign_key: { to_table: :users }
      t.references :merch, null: false, foreign_key: { to_table: :users }

      # Détails de la mission proposée
      t.string :company, null: false      # Client (ex: Lindt)
      t.string :agency, null: false       # Agence (ex: Actiale) - Important pour retrouver le contrat
      t.date :date, null: false
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false

      t.string :store_name
      t.string :store_address
      t.decimal :hourly_rate, precision: 5, scale: 2, default: 11.88
      t.text :message # Le petit mot du FVE

      # État de la proposition
      t.string :status, default: 'pending' # pending, accepted, declined, cancelled

      t.timestamps
    end

    add_index :mission_proposals, :status
  end
end
