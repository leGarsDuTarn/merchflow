import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { key: String };

  connect() {
    // Si la clé existe, on la supprime.
    // Cela signifie que l'utilisateur a résolu le problème, donc on reset le "Snooze".
    if (localStorage.getItem(this.keyValue)) {
      localStorage.removeItem(this.keyValue);
    }
  }
}
