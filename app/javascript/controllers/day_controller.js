import { Controller } from "@hotwired/stimulus";

// Controller principal pour la modale
export default class extends Controller {
  open(event) {
    const cell = event.currentTarget;

    // Infos depuis data-*
    const date = cell.dataset.date;
    const missions = JSON.parse(cell.dataset.missions || "[]");
    const hasMissions = cell.dataset.hasMissions === "true";
    const hasUnavailability = cell.dataset.hasUnavailability === "true";
    const unavId = cell.dataset.unavailabilityId;
    const unavNotes = cell.dataset.unavailabilityNotes || "";

    // Cibles de la modale
    const modalTitle = document.getElementById("dayModalTitle");
    const modalBody = document.getElementById("dayModalBody");
    const modalFooter = document.getElementById("dayModalFooter");

    // ---------------------------------------------------------
    // TITRE
    // ---------------------------------------------------------
    modalTitle.innerHTML = `Actions du ${this.formatDate(date)}`;

    // ---------------------------------------------------------
    // CORPS DE LA MODALE
    // ---------------------------------------------------------
    let bodyHtml = "";

    // Missions
    if (hasMissions) {
      bodyHtml += `<h6 class='fw-bold text-orange'>Missions du jour</h6>`;
      missions.forEach((m) => {
        bodyHtml += `
          <div class="border rounded p-2 mb-2 bg-light">
            <div class="fw-bold">${m.company}</div>
            <div class="text-muted small">${m.start} – ${m.end}</div>
            <a href="/work_sessions/${m.id}" class="btn btn-orange btn-sm w-100 mt-2">
              Voir / Modifier la mission
            </a>
          </div>
        `;
      });
    }

    // Indisponibilité
    if (hasUnavailability) {
      bodyHtml += `
        <h6 class="fw-bold text-danger mt-3">Indisponible</h6>
        <p><strong>Motif :</strong>${
          unavNotes ? " " + unavNotes : ""
        }</p>

        <label class="fw-semibold">Modifier la note</label>
        <textarea id="editUnavNotes" class="form-control" rows="2">${unavNotes}</textarea>
      `;
    }

    // Jour libre
    if (!hasMissions && !hasUnavailability) {
      bodyHtml += `
        <h6 class="fw-bold text-orange mb-2">Ce jour est libre</h6>
        <div class="mb-3">
          <label class="fw-semibold">Raison de l’indisponibilité (optionnel)</label>
          <textarea id="newUnavNotes"
                    class="form-control"
                    rows="2"
                    placeholder="Ex : CP, RDV, repos…"></textarea>
        </div>
      `;
    }

    modalBody.innerHTML = bodyHtml;

    // ---------------------------------------------------------
    // FOOTER : ACTIONS
    // ---------------------------------------------------------
    let footer = "";

    // Ajouter mission (sauf indispo)
    if (!hasUnavailability) {
      footer += `
        <a href="/work_sessions/new?date=${date}"
           class="btn btn-orange fw-bold me-auto">
          Ajouter une mission
        </a>
      `;
    }

    // Rendre indisponible
    if (!hasUnavailability && !hasMissions) {
      footer += `
        <form action="/unavailabilities" method="post" id="newUnavForm">
          <input type="hidden" name="authenticity_token" value="${this.csrf()}">
          <input type="hidden" name="date" value="${date}">
          <input type="hidden" name="notes" id="new_unav_form_notes">
          <button type="submit" class="btn btn-danger">Me rendre indisponible</button>
        </form>
      `;
    }

    // Modifier indispo
    if (hasUnavailability) {
      footer += `
        <form action="/unavailabilities/${unavId}" method="post" id="editUnavForm" class="me-2">
          <input type="hidden" name="authenticity_token" value="${this.csrf()}">
          <input type="hidden" name="_method" value="patch">
          <input type="hidden" name="notes" id="unav_form_notes">
          <button type="submit" class="btn btn-orange fw-bold">Modifier</button>
        </form>
      `;
    }

    // Supprimer l'indispo
    if (hasUnavailability) {
      footer += `
        <form action="/unavailabilities/${unavId}" method="post">
          <input type="hidden" name="authenticity_token" value="${this.csrf()}">
          <input type="hidden" name="_method" value="delete">
          <button type="submit" class="btn btn-secondary">Disponible</button>
        </form>
      `;
    }

    modalFooter.innerHTML = footer;

    // ---------------------------------------------------------
    // OUVRIR LA MODALE
    // ---------------------------------------------------------
    const modal = new bootstrap.Modal(document.getElementById("dayModal"));
    modal.show();

    // ---------------------------------------------------------
    // FIX ICI → ajouter les listeners APRÈS que la modale existe
    // ---------------------------------------------------------
    setTimeout(() => {
      // Création d'indispo avec note
      const newForm = document.getElementById("newUnavForm");
      if (newForm) {
        newForm.addEventListener("submit", () => {
          document.getElementById("new_unav_form_notes").value =
            document.getElementById("newUnavNotes").value;
        });
      }

      // Modification d’indisponibilité
      const editForm = document.getElementById("editUnavForm");
      if (editForm) {
        editForm.addEventListener("submit", () => {
          document.getElementById("unav_form_notes").value =
            document.getElementById("editUnavNotes").value;
        });
      }
    }, 50);
  }

  // Format FR
  formatDate(dateStr) {
    return new Date(dateStr).toLocaleDateString("fr-FR", {
      weekday: "long",
      day: "numeric",
      month: "long",
    });
  }

  csrf() {
    return document.querySelector("meta[name='csrf-token']").content;
  }
}
