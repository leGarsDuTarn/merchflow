import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["target", "template"];

  add(e) {
    e.preventDefault();
    // On remplace NEW_RECORD par un ID unique (timestamp)
    const content = this.templateTarget.innerHTML.replace(
      /NEW_RECORD/g,
      new Date().getTime()
    );
    this.targetTarget.insertAdjacentHTML("beforeend", content);
  }

  remove(e) {
    e.preventDefault();
    const wrapper = e.target.closest(".nested-form-wrapper");

    // Si c'est une ligne déjà en base, on la cache et on met _destroy à 1
    if (wrapper.dataset.newRecord === "true") {
      wrapper.remove();
    } else {
      wrapper.style.display = "none";
      wrapper.querySelector("input[name*='_destroy']").value = 1;
    }
  }
}
