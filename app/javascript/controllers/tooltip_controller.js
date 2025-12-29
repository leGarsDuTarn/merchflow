// app/javascript/controllers/tooltip_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    // Initialiser les tooltips sur tous les éléments enfants qui ont l'attribut data-bs-toggle="tooltip"
    this.tooltips = [
      ...this.element.querySelectorAll('[data-bs-toggle="tooltip"]'),
    ].map((tooltipTriggerEl) => new bootstrap.Tooltip(tooltipTriggerEl));
  }

  disconnect() {
    // Nettoyer les tooltips quand on quitte la page (pour éviter qu'ils restent figés)
    if (this.tooltips) {
      this.tooltips.forEach((tooltip) => tooltip.dispose());
    }
  }
}
