class AddFranceTravailSnapshotsToJobApplications < ActiveRecord::Migration[8.1]
  def change
    change_table :job_applications do |t|
      t.string :job_title_snapshot
      t.string :company_name_snapshot
      t.string :location_snapshot
      t.string :contract_type_snapshot
      t.datetime :start_date_snapshot
      t.datetime :end_date_snapshot

      # Optionnel mais recommandé : figer le taux horaire (decimal 5,2)
      t.decimal :hourly_rate_snapshot, precision: 5, scale: 2
    end
  end
end
