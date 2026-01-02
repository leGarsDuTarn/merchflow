class AddJobBoardAndUpdateSmic < ActiveRecord::Migration[8.1]
  def change
    # ==================================================================
    # 1. MISE À JOUR DU SMIC (12.02)
    # ==================================================================

    # On met à jour WorkSessions et MissionProposals
    change_column_default :work_sessions, :hourly_rate, from: 11.88, to: 12.02
    change_column_default :mission_proposals, :hourly_rate, from: 11.88, to: 12.02

    # ==================================================================
    # 2. CRÉATION DU SYSTÈME D'ANNONCES (JOB OFFERS)
    # ==================================================================
    create_table :job_offers do |t|
      t.references :fve, null: false, foreign_key: { to_table: :users }

      t.string :title, null: false
      t.text :description, null: false
      t.string :mission_type, null: false
      t.string :contract_type, null: false
      t.string :company_name, null: false
      t.integer :headcount_required, default: 1, null: false

      t.string :store_name
      t.string :address
      t.string :zipcode
      t.string :city
      t.string :department_code

      # --- GESTION DU TEMPS ---
      t.datetime :start_date, null: false
      t.datetime :end_date, null: false
      t.datetime :break_start_time
      t.datetime :break_end_time
      t.integer :duration_minutes, default: 0, null: false

      # Financier (SMIC 12.02)
      t.decimal :hourly_rate, precision: 5, scale: 2, default: "12.02", null: false

      # Défraiement
      t.boolean :km_unlimited, default: false
      t.decimal :km_rate, precision: 5, scale: 2
      t.decimal :km_limit, precision: 5, scale: 2

      t.string :status, default: 'draft', null: false

      t.timestamps
    end

    add_index :job_offers, [:status, :department_code, :mission_type], name: 'index_job_offers_search'

    # ==================================================================
    # 3. CRÉATION DES CANDIDATURES
    # ==================================================================
    create_table :job_applications do |t|
      t.references :job_offer, null: false, foreign_key: true
      t.references :merch, null: false, foreign_key: { to_table: :users }

      t.string :status, default: 'pending'
      t.text :message

      t.timestamps
    end

    add_index :job_applications, [:job_offer_id, :merch_id], unique: true

    # ==================================================================
    # 4. SETTINGS MERCH
    # ==================================================================
    add_column :merch_settings, :preferred_departments, :string, array: true, default: []
    add_index :merch_settings, :preferred_departments, using: 'gin'
  end
end
