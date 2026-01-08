class AddNightHoursToJobOffers < ActiveRecord::Migration[8.1]
  def change
    add_column :job_offers, :night_start, :integer, default: 21, null: false
    add_column :job_offers, :night_end, :integer, default: 6, null: false
  end
end
