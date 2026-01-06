import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["checkbox", "input", "container"];

  connect() {
    // Vérifie l'état initial au chargement
    this.toggle();
  }

  toggle() {
    const isUnlimited = this.checkboxTarget.checked;

    // Active/désactive le champ de distance
    this.inputTarget.disabled = isUnlimited;

    if (isUnlimited) {
      // Si illimité : vide le champ et grise le conteneur
      this.inputTarget.value = "";
      this.containerTarget.style.opacity = "0.4";
      this.containerTarget.style.pointerEvents = "none";
    } else {
      // Si limité : réactive tout
      this.containerTarget.style.opacity = "1";
      this.containerTarget.style.pointerEvents = "auto";
      // Optionnel : remet le focus sur l'input
      this.inputTarget.focus();
    }
  }
}
