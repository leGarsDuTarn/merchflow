class RemoveOldPrivacyFieldsFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :allow_identity, :boolean
    remove_column :users, :allow_email, :boolean
    remove_column :users, :allow_phone, :boolean
  end
end
