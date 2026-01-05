class AddContactToJobOffers < ActiveRecord::Migration[8.1]
  def change
    add_column :job_offers, :contact_email, :string
    add_column :job_offers, :contact_phone, :string
  end
end
