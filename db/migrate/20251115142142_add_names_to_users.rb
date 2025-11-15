class AddNamesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :firstname, :string, null: false, default: ""
    add_column :users, :lastname, :string, null: false, default: ""
    add_column :users, :username, :string, null: false, default: ""

    # Empêche définitivement les doublons au niveau SQL
    add_index :users, :username, unique: true
  end
end

