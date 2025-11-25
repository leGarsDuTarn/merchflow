import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "clearButton"];
  static values = { url: String };

  connect() {
    this.timeout = null;
    // Vérifier l'état initial au chargement (important pour Turbo)
    this.toggleClearButton();
  }

  // Appelé automatiquement quand Turbo recharge la page
  // (important pour maintenir l'état après navigation)
  disconnect() {
    clearTimeout(this.timeout);
  }

  // Méthode de recherche avec délai
  search() {
    clearTimeout(this.timeout);
    this.toggleClearButton(); // Mise à jour immédiate de la croix

    this.timeout = setTimeout(() => {
      const query = this.inputTarget.value.trim();

      const url =
        query === ""
          ? this.urlValue
          : `${this.urlValue}?query=${encodeURIComponent(query)}`;

      Turbo.visit(url);
    }, 4000);
  }

  // Méthode pour effacer
  clear(event) {
    event.preventDefault();

    // Vider le champ
    this.inputTarget.value = "";

    // Masquer immédiatement la croix
    this.clearButtonTarget.style.display = "none";

    // Naviguer vers la page sans recherche
    Turbo.visit(this.urlValue);
  }

  // Affiche/Cache la croix
  toggleClearButton() {
    if (this.hasInputTarget && this.hasClearButtonTarget) {
      const isEmpty = this.inputTarget.value.trim() === "";
      this.clearButtonTarget.style.display = isEmpty ? "none" : "inline";
    }
  }
}
