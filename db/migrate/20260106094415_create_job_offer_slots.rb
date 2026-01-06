class CreateJobOfferSlots < ActiveRecord::Migration[8.1]
  def change
    create_table :job_offer_slots do |t|
      t.references :job_offer, null: false, foreign_key: true

      # Empêche ces champs d'être vides en DB
      t.date :date, null: false
      t.time :start_time, null: false
      t.time :end_time, null: false

      # Les pauses restent optionnelles (donc pas de null: false)
      t.time :break_start_time
      t.time :break_end_time

      t.timestamps
    end
  end
end
