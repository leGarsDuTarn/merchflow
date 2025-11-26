class CreateFveInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :fve_invitations do |t|
      t.string :email, null: false
      t.string :token, null: false

      t.boolean :premium, default: false, null: false
      t.string :agency
      t.datetime :expires_at

      t.boolean :used, default: false, null: false

      t.timestamps
    end

    add_index :fve_invitations, :token, unique: true
  end
end
