import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { url: String };

  toggle(event) {
    const checkbox = event.target;
    const url = this.urlValue;

    // Envoie la requête au serveur sans recharger la page
    fetch(url, {
      method: "PATCH", // On utilise PATCH comme défini dans tes routes (probablement)
      headers: {
        "X-CSRF-Token": document.querySelector("[name='csrf-token']").content,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
    }).then((response) => {
      if (!response.ok) {
        // En cas d'erreur serveur, on annule visuellement le changement
        checkbox.checked = !checkbox.checked;
        alert("Impossible de modifier ce paramètre pour le moment.");
      }
    });
  }
}
