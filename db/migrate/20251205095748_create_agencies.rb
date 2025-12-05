class CreateAgencies < ActiveRecord::Migration[8.1]
  def change
    create_table :agencies do |t|
      # 'code' sera la clé de liaison (ex: 'actiale', 'rma'). Il doit être unique.
      t.string :code, null: false
      t.string :label, null: false

      t.timestamps
    end
    add_index :agencies, :code, unique: true
  end
end
