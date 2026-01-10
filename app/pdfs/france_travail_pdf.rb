class FranceTravailPdf < Prawn::Document
  def initialize(grouped_sessions, user, month, year)
    # Marges confortables pour l'impression
    super(page_size: "A4", margin: 40)
    @grouped = grouped_sessions
    @user = user
    @month = month
    @year = year

    # CHARTE GRAPHIQUE
    @orange     = "FD7E14"
    @dark_grey  = "333333"
    @light_grey = "F8F9FA"
    @border_grey = "E9ECEF"

    # Lancement
    header
    content
    footer
  end

  def header
    # Titre Principal
    text "Aide à la Déclaration Mensuelle", size: 20, style: :bold, color: @orange
    text "Document justificatif pour France Travail / Pôle Emploi", size: 10, color: @dark_grey

    move_down 20

    # Encadré Info Candidat
    bounding_box([0, cursor], width: bounds.width, height: 90) do
      stroke_color @border_grey
      stroke_bounds

      indent(15) do
        move_down 10
        text "Période : #{I18n.l(Date.new(@year, @month), format: "%B %Y").capitalize}", size: 12, style: :bold
        move_down 5
        text "Candidat : #{@user.firstname} #{@user.lastname}", size: 10
        text "Email : #{@user.email}", size: 10
        move_down 10
      end
    end
    move_down 30
  end

  def content
    if @grouped.empty?
      move_down 50
      text "Aucune mission effectuée sur cette période.", align: :center, style: :italic, color: "999999"
    else
      @grouped.each_with_index do |(agency, sessions), index|
        # Vérifier s'il reste assez d'espace (environ 200pt pour un bloc)
        if cursor < 220
          start_new_page
        end

        render_agency_block(agency, sessions)

        # Ajouter un espace entre les blocs sauf pour le dernier
        move_down 20 unless index == @grouped.size - 1
      end
    end
  end

  def render_agency_block(agency, sessions)
    # --- CALCULS ---
    total_minutes = sessions.sum(&:duration_minutes)
    hours = (total_minutes / 60.0).round(1)
    base_brut = sessions.sum(&:brut)
    total_cp = sessions.sum(&:amount_cp)
    declare = base_brut + total_cp

    # Hauteur approximative du bloc pour éviter les coupures
    block_height = 200

    # Si pas assez de place, nouvelle page
    if cursor < block_height
      start_new_page
    end

    # Position de départ du bloc
    start_y = cursor

    # --- CADRE AGENCE ---
    bounding_box([0, start_y], width: bounds.width) do

      # 1. En-tête Gris de l'Agence (hauteur fixe)
      header_height = 35
      fill_color @light_grey
      fill_rectangle [0, bounds.top], bounds.width, header_height
      fill_color @dark_grey

      # Texte de l'en-tête
      move_down 10
      indent(15) do
        text agency.to_s.upcase, size: 12, style: :bold, color: @orange
      end
      move_down 5

      # 2. Corps des chiffres
      indent(15, 15) do
        move_down 15

        # Ligne Heures
        display_row("Heures effectuées", "#{hours} h", bold: true)
        move_down 10

        stroke_color @border_grey
        stroke_horizontal_rule
        move_down 10

        # Ligne Brut Base
        display_row("Salaire Brut (Base)", format_euro(base_brut))
        move_down 5

        # Ligne CP
        display_row("Congés Payés (CP)", format_euro(total_cp))
        move_down 15

        # 3. TOTAL (Encadré Orange) - hauteur fixe
        total_box_height = 55

        bounding_box([0, cursor], width: bounds.width - 30, height: total_box_height) do
          # Fond Orange très pâle
          fill_color "FFF3E0"
          fill_rectangle [0, bounds.top], bounds.width, total_box_height
          fill_color @dark_grey

          move_down 12
          indent(10, 10) do
            # Label à gauche
            float do
              text "MONTANT BRUT À DÉCLARER", size: 10, style: :bold, color: @orange
              move_down 2
              text "(Base + CP, hors primes IFM)", size: 8, style: :italic, color: "999999"
            end

            # Montant à droite
            move_down 5
            text format_euro(declare), size: 16, style: :bold, color: @orange, align: :right
          end
        end

        move_down 15
      end

      # Bordure globale du bloc
      stroke_color @border_grey
      stroke_bounds
    end
  end

  def footer
    # Toujours en bas de la dernière page
    if page_count > 0
      go_to_page(page_count)

      # Aller en bas de page
      bounding_box([0, 60], width: bounds.width) do
        text "Document généré par MerchFlow pour faciliter vos démarches.",
             size: 8, align: :center, color: "AAAAAA"
        move_down 2
        text "Vérifiez toujours ces montants avec vos fiches de paie définitives.",
             size: 8, align: :center, style: :bold, color: "AAAAAA"
      end
    end
  end

  private

  # Helper pour afficher une ligne Gauche / Droite
  def display_row(label, value, bold: false)
    float do
      text label, size: 10, color: "666666"
    end
    style = bold ? :bold : :normal
    text value, size: 10, style: style, align: :right, color: "000000"
  end

  # Helper pour formater l'argent
  def format_euro(amount)
    sprintf("%.2f €", amount).gsub('.', ',')
  end
end
