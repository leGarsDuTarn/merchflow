class RemoveAllowContactFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :allow_contact, :boolean
  end
end
