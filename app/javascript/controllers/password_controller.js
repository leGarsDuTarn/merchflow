import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["field", "icon"];

  // Cible : Le champ de mot de passe (type=password/text)
  // Cible : L'icône (œil)

  toggle() {
    const isPassword = this.fieldTarget.type === "password";

    // 1. Basculer le type du champ
    this.fieldTarget.type = isPassword ? "text" : "password";

    // 2. Changer l'icône de l'œil
    this.iconTarget.classList.toggle("fa-eye-slash", !isPassword);
    this.iconTarget.classList.toggle("fa-eye", isPassword);
  }
}
