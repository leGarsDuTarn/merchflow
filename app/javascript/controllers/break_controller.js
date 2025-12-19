import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["fields"];

  toggle(event) {
    if (event.target.checked) {
      this.fieldsTarget.classList.remove("d-none");
    } else {
      this.fieldsTarget.classList.add("d-none");
      // Optionnel : vider les champs si on décoche
      this.fieldsTarget
        .querySelectorAll("input")
        .forEach((i) => (i.value = ""));
    }
  }
}
