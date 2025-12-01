class AddAgencyToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :agency, :string
    add_index :users, :agency
  end
end
