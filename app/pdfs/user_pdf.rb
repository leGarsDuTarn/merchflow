class UserPdf < Prawn::Document
  def initialize(user)
    super(page_size: 'A4', margin: 40)
    @user = user

    font "Helvetica"

    # 1. Titre principal (<h1>)
    title_header

    # 2. Les différentes sections (<div> <h2> <p>)
    identity_section
    contact_section
    address_section
    agency_section
    account_info_section
    security_section

    # 3. Pied de page (Bonus pour faire pro)
    footer
  end

  private

  # --- Helpers pour le style ---

  # Cette méthode remplace tes <div class="section"> et <span class="label">
  def draw_section(title, items)
    move_down 20
    # Le <h2>
    text title, size: 16, style: :bold, color: "333333"
    stroke do
      stroke_color "CCCCCC"
      line_width 1
      horizontal_line 0, 100, at: cursor - 5 # Petite ligne soulignée sous le titre
    end
    move_down 10

    # Les <p>
    items.each do |label, value|
      formatted_text [
        { text: "#{label} : ", style: :bold, color: "555555" }, # class="label"
        { text: value.to_s, color: "000000" }
      ]
      move_down 5
    end
  end

  # --- Contenu ---

  def title_header
    # <h1>Export des donnees personnelles (RGPD)</h1>
    text "Export des données personnelles (RGPD)", size: 24, style: :bold, align: :center
    move_down 10
    # <hr>
    stroke_horizontal_rule
    move_down 10
  end

  def identity_section
    draw_section("Identité du compte", [
      ["Nom", @user.lastname],
      ["Prénom", @user.firstname],
      ["Nom complet", "#{@user.firstname} #{@user.lastname}"],
      ["Nom d'utilisateur", @user.username],
      ["Rôle", @user.role]
    ])
  end

  def contact_section
    draw_section("Informations de contact", [
      ["Email", @user.email],
      ["Téléphone", @user.phone_number.presence || "Non renseigné"]
    ])
  end

  def address_section
    draw_section("Adresse", [
      ["Adresse", @user.address.presence || "Non renseignée"],
      ["Code postal", @user.zipcode.presence || "Non renseigné"],
      ["Ville", @user.city.presence || "Non renseignée"]
    ])
  end

  def agency_section
    draw_section("Agences et statut", [
      ["Agence", @user.agency.presence || "Aucune"],
      ["Premium", @user.premium ? "Oui" : "Non"]
    ])
  end

  def account_info_section
    draw_section("Informations de compte", [
      ["Date de création", @user.created_at.strftime("%d/%m/%Y %H:%M")],
      ["Dernière mise à jour", @user.updated_at.strftime("%d/%m/%Y %H:%M")]
    ])
  end

  def security_section
    draw_section("Sécurité et Authentification (Devise)", [
      ["Reset password token présent", @user.reset_password_token.present? ? "Oui" : "Non"],
      ["Reset password envoyé le", @user.reset_password_sent_at&.strftime("%d/%m/%Y %H:%M") || "Aucun"],
      ["Remember created at", @user.remember_created_at&.strftime("%d/%m/%Y %H:%M") || "Aucun"]
    ])
  end

  def footer
    move_down 30
    text "Document généré automatiquement par MerchFlow.", size: 8, align: :center, color: "999999"
  end
end
