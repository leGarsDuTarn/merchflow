class AddPrivacyAndPremiumToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :allow_email, :boolean, default: false, null: false
    add_column :users, :allow_phone, :boolean, default: false, null: false
    add_column :users, :allow_identity, :boolean, default: false, null: false
    add_column :users, :premium, :boolean, default: false, null: false
  end
end
