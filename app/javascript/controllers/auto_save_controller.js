import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["flash"];

  submit(event) {
    // Trouve le formulaire parent
    const form = event.target.closest("form");

    if (form) {
      // Utilise requestSubmit si disponible, sinon submit()
      if (form.requestSubmit) {
        form.requestSubmit();
      } else {
        form.submit();
      }
    }
  }

  showFlash() {
    if (!this.hasFlashTarget) return;

    this.flashTarget.classList.remove("d-none");
    setTimeout(() => {
      this.flashTarget.classList.add("d-none");
    }, 1200);
  }
}
