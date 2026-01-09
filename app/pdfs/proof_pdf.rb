# app/pdfs/proof_pdf.rb
class ProofPdf < Prawn::Document
  def initialize(applications, user)
    super(page_size: "A4", margin: 40)
    @applications = applications
    @user = user

    header
    text_content
    table_content
    footer
  end

  def header
    # Titre principal
    text "Attestation de Candidature", size: 24, style: :bold, align: :center
    move_down 10
    text "Preuve de candidature - www.merchflow.fr", size: 10, align: :center, color: "666666"

    move_down 20
    text "Généré le #{Time.now.strftime('%d/%m/%Y à %H:%M')}", size: 9, align: :right, color: "777777"
    move_down 20
  end

  def text_content
    # Informations du candidat
    bounding_box([0, cursor], width: 540) do
      text "Candidat : #{@user.firstname} #{@user.lastname}", size: 12, style: :bold
      text "Email : #{@user.email}", size: 10
      move_down 5
    end

    move_down 20
    text "Ce document certifie que le candidat susnommé a effectué les démarches de candidature suivantes via notre plateforme Merchlow. Les informations ci-dessous sont extraites de notre base de données et font foi des actions entreprises à la date indiquée.", size: 10, style: :italic
    move_down 25
  end

  def table_content
    # Définition des en-têtes
    table_data = [["Date Envoi", "Intitulé du poste", "Agence / Entreprise", "Dates de la Mission", "Statut"]]

    @applications.each do |app|
      # Récupération sécurisée des données (Snapshot ou Offre)
      job_title   = app.job_title_snapshot.presence || app.job_offer&.title || "Mission archivée"
      agency_name = app.company_name_snapshot.presence || app.job_offer&.company_name || "N/A"

      # Gestion des dates de mission
      m_start = app.start_date_snapshot || app.job_offer&.start_date
      m_end   = app.end_date_snapshot   || app.job_offer&.end_date
      mission_period = if m_start && m_end
                         "Du #{m_start.strftime('%d/%m/%y')}\nau #{m_end.strftime('%d/%m/%y')}"
                       else
                         "N/A"
                       end

      table_data << [
        app.created_at.strftime("%d/%m/%Y"),
        job_title,
        agency_name,
        mission_period,
        translate_status(app.status)
      ]
    end

    # Rendu de la table
    table(table_data, header: true, width: 515) do
      row(0).font_style = :bold
      row(0).background_color = "F2F2F2"
      row(0).align = :center

      # Alternance de couleurs pour la lisibilité
      self.row_colors = ["FFFFFF", "F9F9F9"]

      # Style des cellules
      self.cell_style = { size: 9, vertical_padding: 8, border_color: "DDDDDD" }

      # Réglage précis des largeurs (Total 515)
      columns(0).width = 70  # Date
      columns(1).width = 130 # Poste
      columns(2).width = 130 # Agence
      columns(3).width = 95  # Dates Mission
      columns(4).width = 90  # Statut

      # Alignement du statut au centre
      columns(4).align = :center
    end
  end

  def footer
    move_down 40
    text "Ce document est généré électroniquement et ne nécessite pas de signature.", size: 8, align: :center, color: "999999"
    move_down 5
    text "Pour faire valoir ce que de droit.", size: 9, align: :center, style: :bold, color: "666666"
  end

  private

  def translate_status(status)
    case status
    when 'pending'  then 'En attente'
    when 'accepted' then 'Acceptée'
    when 'rejected' then 'Non retenue'
    when 'archived' then 'Clôturée'
    else status.to_s.capitalize
    end
  end
end
