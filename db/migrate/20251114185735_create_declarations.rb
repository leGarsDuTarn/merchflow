class CreateDeclarations < ActiveRecord::Migration[8.1]
  def change
    create_table :declarations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :contract, null: false, foreign_key: true

      t.integer :year, null: false           # ex: 2025
      t.integer :month, null: false          # ex: 11

      t.string  :employer_name, null: false  # Actiale, RMA…

      t.integer :total_minutes, null: false, default: 0
      t.decimal :brut_with_cp, precision: 8, scale: 2, null: false, default: 0.0

      t.string :status, null: false, default: "draft" # draft / validated

      t.timestamps
    end

    add_index :declarations, [:user_id, :year, :month]
  end
end
