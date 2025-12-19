require 'rails_helper'

RSpec.describe 'Dashboard Notifications', type: :system, js: true do
  # 1. On crée un utilisateur Merch
  let(:user) { create(:user, :merch) }

  # CORRECTION ICI : Au lieu de create(:merch_setting, user: user...),
  # on passe par l'association du user pour éviter l'erreur "undefined method user="
  let!(:settings) do
    # On récupère le setting s'il existe déjà (via la factory user) ou on en construit un
    s = user.merch_setting || user.build_merch_setting
    # On applique les paramètres pour le test (Mode Privé)
    s.share_planning = false
    s.allow_identity = false
    s.save!
    s
  end

  before do
    driven_by :selenium_chrome_headless
    sign_in user
    visit dashboard_path
  end

  # ====================================================================
  # TEST 1 : ASTUCE MOBILE (Disparition définitive)
  # ====================================================================
  context "Carte Astuce Mobile" do
    it "disparaît définitivement après fermeture" do
      key = "hint_mobile_v3"

      # Vérifier qu'elle est là au début
      expect(page).to have_selector("[data-dismissible-key-value='#{key}']", visible: true)

      # Cliquer sur la croix
      find("[data-dismissible-key-value='#{key}'] .btn-close").click

      # Vérifier qu'elle disparaît
      expect(page).to have_no_selector("[data-dismissible-key-value='#{key}']")

      # Rafraîchir la page : elle ne doit PAS revenir
      visit dashboard_path
      expect(page).to have_no_selector("[data-dismissible-key-value='#{key}']")
    end
  end

  # ====================================================================
  # TEST 2 : ALERTE BOOST (Récurrence 5 jours)
  # ====================================================================
  context "Alerte Boost (Snooze 5 jours)" do
    it "reste cachée pendant 5 jours puis réapparaît" do
      key = "boost_visib_v3"

      # A. Elle est là car share_planning est false
      expect(page).to have_selector("[data-dismissible-key-value='#{key}']", visible: true)

      # B. On ferme la carte
      find("[data-dismissible-key-value='#{key}'] .btn-close").click
      expect(page).to have_no_selector("[data-dismissible-key-value='#{key}']")

      # C. On revient tout de suite (Simulation < 5 jours)
      visit dashboard_path
      expect(page).to have_no_selector("[data-dismissible-key-value='#{key}']")

      # --- MANIPULATION DU TEMPS (TRICHE) ---
      # D. On injecte une date vieille de 2 jours
      date_2_days_ago = 2.days.ago.iso8601
      page.execute_script("localStorage.setItem('#{key}', JSON.stringify({date: '#{date_2_days_ago}'}))")

      visit dashboard_path
      expect(page).to have_no_selector("[data-dismissible-key-value='#{key}']") # Toujours caché

      # E. On injecte une date vieille de 6 jours
      date_6_days_ago = 6.days.ago.iso8601
      page.execute_script("localStorage.setItem('#{key}', JSON.stringify({date: '#{date_6_days_ago}'}))")

      visit dashboard_path
      expect(page).to have_selector("[data-dismissible-key-value='#{key}']", visible: true) # REVENU !
    end
  end

  # ====================================================================
  # TEST 3 : LE "SMART RESET" (Logique Business)
  # ====================================================================
  context "Smart Reset (Nettoyage quand l'user est en règle)" do
    it "réapparaît immédiatement si l'user repasse en privé, même s'il l'avait fermée" do
      key = "boost_visib_v3"

      # ETAPE 1 : L'user est en Privé, il voit l'alerte et la ferme (Snooze)
      expect(page).to have_selector("[data-dismissible-key-value='#{key}']", visible: true)
      find("[data-dismissible-key-value='#{key}'] .btn-close").click
      expect(page).to have_no_selector("[data-dismissible-key-value='#{key}']")

      # ETAPE 2 : L'user active ses paramètres (Bon élève)
      # Côté serveur, l'alerte ne s'affiche plus.
      # Le contrôleur "storage-cleaner" doit supprimer la clé du localStorage ici.
      settings.update(share_planning: true, allow_identity: true)
      visit dashboard_path

      expect(page).to have_no_selector("[data-dismissible-key-value='#{key}']")

      # ETAPE 3 : L'user désactive à nouveau ses paramètres (Mauvais élève)
      settings.update(share_planning: false)
      visit dashboard_path

      # VERDICT : L'alerte doit être là immédiatement !
      expect(page).to have_selector("[data-dismissible-key-value='#{key}']", visible: true)
    end
  end
end
