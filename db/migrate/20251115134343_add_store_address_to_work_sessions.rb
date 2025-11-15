class AddStoreAddressToWorkSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :work_sessions, :store_full_address, :string
  end
end
