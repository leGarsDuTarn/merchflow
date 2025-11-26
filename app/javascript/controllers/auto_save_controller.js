import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["flash"];

  submit() {
    // auto submit du formulaire
    this.element.requestSubmit();
  }

  showFlash() {
    if (!this.flashTarget) return;

    this.flashTarget.classList.remove("d-none");
    setTimeout(() => {
      this.flashTarget.classList.add("d-none");
    }, 1200);
  }
}
