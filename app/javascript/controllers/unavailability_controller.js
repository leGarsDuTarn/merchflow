import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  new(event) {
    const date = event.currentTarget.dataset.date;

    const body = document.getElementById("dayModalBody");
    const footer = document.getElementById("dayModalFooter");

    body.innerHTML = `
      <div class="mb-3">
        <label class="form-label fw-semibold">Date</label>
        <input type="text" class="form-control" value="${date}" disabled>
      </div>

      <div class="mb-3">
        <label class="form-label fw-semibold">Notes (optionnel)</label>
        <textarea class="form-control" id="notes"></textarea>
      </div>
    `;

    footer.innerHTML = `
      <form method="post" action="/unavailabilities" data-turbo="false" class="w-100">
        <input type="hidden" name="unavailability[date]" value="${date}">
        <input type="hidden" name="unavailability[notes]" id="hidden_notes">

        <button type="submit" class="btn btn-orange w-100 fw-bold"
          onclick="document.getElementById('hidden_notes').value = document.getElementById('notes').value;">
          Confirmer
        </button>
      </form>
    `;
  }

  edit(event) {
    const id = event.currentTarget.dataset.id;
    const date = event.currentTarget.dataset.date;
    const notes = event.currentTarget.dataset.notes || "";

    const body = document.getElementById("dayModalBody");
    const footer = document.getElementById("dayModalFooter");

    body.innerHTML = `
      <div class="mb-3">
        <label class="form-label fw-semibold">Date</label>
        <input type="text" class="form-control" value="${date}" disabled>
      </div>

      <div class="mb-3">
        <label class="form-label fw-semibold">Notes</label>
        <textarea class="form-control" id="edit_notes">${notes}</textarea>
      </div>
    `;

    footer.innerHTML = `
      <form method="post" action="/unavailabilities/${id}" data-turbo="false" class="w-100">
        <input type="hidden" name="_method" value="patch">
        <input type="hidden" name="unavailability[notes]" id="edit_hidden_notes">

        <button type="submit" class="btn btn-orange w-100 fw-bold"
          onclick="document.getElementById('edit_hidden_notes').value = document.getElementById('edit_notes').value;">
          Mettre à jour
        </button>
      </form>
    `;
  }
}
