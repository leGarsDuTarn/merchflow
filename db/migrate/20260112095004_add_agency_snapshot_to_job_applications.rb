class AddAgencySnapshotToJobApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :job_applications, :agency_snapshot, :string
  end
end
