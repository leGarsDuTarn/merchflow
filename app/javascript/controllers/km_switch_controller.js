import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["checkbox", "input", "container"];

  connect() {
    // On lance la fonction au chargement pour vérifier l'état initial
    this.toggle();
  }

  toggle() {
    if (this.checkboxTarget.checked) {
      // Si coché (Illimité) : On désactive le champ et on grise
      this.inputTarget.disabled = true;
      this.inputTarget.value = ""; // Optionnel : on vide le champ
      this.containerTarget.style.opacity = "0.4";
      this.containerTarget.style.pointerEvents = "none";
    } else {
      // Si décoché : On réactive tout
      this.inputTarget.disabled = false;
      this.containerTarget.style.opacity = "1";
      this.containerTarget.style.pointerEvents = "auto";
    }
  }
}
