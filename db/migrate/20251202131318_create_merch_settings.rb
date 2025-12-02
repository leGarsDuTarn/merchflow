class CreateMerchSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :merch_settings do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }

      t.boolean :share_planning, default: false
      t.boolean :allow_contact_message, default: false
      t.boolean :allow_contact_phone, default: false
      t.boolean :allow_contact_email, default: false
      t.boolean :allow_none, default: false

      t.boolean :role_merch, default: true
      t.boolean :role_anim, default: false

      t.timestamps
    end
  end
end

