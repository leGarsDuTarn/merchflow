class AddJobOfferToWorkSessions < ActiveRecord::Migration[8.1]
  def change
    # Autorise le null car toutes les sessions ne viennent pas forcément d'une offre
    add_reference :work_sessions, :job_offer, null: true, foreign_key: true
  end
end
