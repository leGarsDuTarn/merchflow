class CreateFavorites < ActiveRecord::Migration[8.1]
  def change
    create_table :favorites do |t|
      t.references :fve, null: false, foreign_key: { to_table: :users }
      t.references :merch, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
    # Empêche d'ajouter le même merch 2 fois en favori
    add_index :favorites, %i[fve_id merch_id], unique: true
  end
end
