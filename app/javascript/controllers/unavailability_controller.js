// app/javascript/controllers/unavailability_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["editId", "editDate", "editNotes", "editForm"];

  openEdit(event) {
    const id = event.currentTarget.dataset.id;
    const date = event.currentTarget.dataset.date;
    const notes = event.currentTarget.dataset.notes || "";

    this.editIdTarget.value = id;
    this.editDateTarget.value = date;
    this.editNotesTarget.value = notes;

    this.editFormTarget.action = `/unavailabilities/${id}`;
  }
}
