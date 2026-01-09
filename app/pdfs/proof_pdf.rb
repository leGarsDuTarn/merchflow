# app/pdfs/proof_pdf.rb
class ProofPdf < Prawn::Document
  def initialize(applications, user)
    super()
    @applications = applications
    @user = user

    header
    text_content
    table_content
    footer
  end

  def header
    # Tu peux ajouter ton logo ici si tu veux
    # image "#{Rails.root}/app/assets/images/logo.png", width: 100, at: [0, 750]

    text "Attestation de Candidature", size: 24, style: :bold, align: :center
    move_down 20
    text "Généré le #{Time.now.strftime('%d/%m/%Y')}", size: 10, align: :right, color: "777777"
    move_down 20
  end

  def text_content
    text "Candidat : #{@user.firstname} #{@user.lastname}", size: 14, style: :bold
    text "Email : #{@user.email}", size: 10
    move_down 30
    text "Ce document certifie que le candidat susnommé a effectué les démarches de candidature suivantes via notre plateforme. Les informations ci-dessous font foi des actions entreprises à la date indiquée.", size: 10, style: :italic
    move_down 20
  end

  def table_content
    # Les en-têtes du tableau
    table_data = [["Date", "Intitulé du poste", "Entreprise", "Lieu", "Statut actuel"]]

    @applications.each do |app|
      table_data << [
      app.created_at.strftime("%d/%m/%Y"),
      # Si le snapshot est vide, on tente de prendre l'info sur l'offre en direct
      app.job_title_snapshot.presence || app.job_offer&.title || "N/A",
      app.company_name_snapshot.presence || app.job_offer&.company_name || "N/A",
      app.location_snapshot.presence || (app.job_offer ? "#{app.job_offer.city} (#{app.job_offer.zipcode})" : "N/A"),
      translate_status(app.status)
    ]
  end

    table(table_data) do
      row(0).font_style = :bold
      row(0).background_color = "EEEEEE"
      self.header = true
      self.row_colors = ["FFFFFF", "F9F9F9"]
      self.width = 540 # Largeur max A4

      # Ajustement des colonnes
      columns(0).width = 70
      columns(4).width = 80
    end
  end

  def footer
    move_down 30
    text "Pour faire valoir ce que de droit.", size: 8, align: :center, color: "999999"
  end

  private

  def translate_status(status)
    case status
    when 'pending' then 'En attente'
    when 'accepted' then 'Acceptée'
    when 'rejected' then 'Non retenu'
    when 'archived' then 'Clôturée' # Le cas où le FVE a supprimé
    else status
    end
  end
end
