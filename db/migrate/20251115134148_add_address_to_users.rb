class AddAddressToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :address, :string
    add_column :users, :zipcode, :string
    add_column :users, :city, :string
  end
end
