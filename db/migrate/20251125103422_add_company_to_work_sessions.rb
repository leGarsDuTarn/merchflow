class AddCompanyToWorkSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :work_sessions, :company, :string
  end
end
