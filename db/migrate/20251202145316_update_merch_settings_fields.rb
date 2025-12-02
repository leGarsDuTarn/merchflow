class UpdateMerchSettingsFields < ActiveRecord::Migration[8.1]
  def change
    # 1. On précise bien la table :merch_settings en premier argument
    add_column :merch_settings, :share_address, :boolean, default: false, null: false
    add_column :merch_settings, :allow_identity, :boolean, default: false, null: false
    add_column :merch_settings, :accept_mission_proposals, :boolean, default: false, null: false

    # 2. INDISPENSABLE pour le choix strict
    add_column :merch_settings, :preferred_contact_channel, :string, default: 'phone'
  end
end
