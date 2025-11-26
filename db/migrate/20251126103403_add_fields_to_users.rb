class AddFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :phone_number, :string
    # Le merch décide s’il partage son email + téléphone
    add_column :users, :allow_contact, :boolean, default: false
    # Default 0 -> merch par default voir model user
    add_column :users, :role, :integer, default: 0
  end
end
