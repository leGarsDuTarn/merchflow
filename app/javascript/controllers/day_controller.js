import { Controller } from "@hotwired/stimulus";

// Controller principal pour la modale
export default class extends Controller {
  open(event) {
    const cell = event.currentTarget;

    // Infos venant du data-*
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

    // --- Missions ----------------------------------------------------
    if (hasMissions) {
      bodyHtml += `<h6 class="fw-bold text-orange">Missions du jour</h6>`;

      missions.forEach((m) => {
        bodyHtml += `
          <div class="border rounded p-2 mb-2 bg-light">
            <div class="fw-bold">${m.company}</div>
            <div class="text-muted small">${m.start} – ${m.end}</div>

            <a href="/work_sessions/${m.id}"
               class="btn btn-orange btn-sm w-100 mt-2">
               Voir / Modifier la mission
            </a>
          </div>
        `;
      });
    }

    // --- Indisponibilité --------------------------------------------
    if (hasUnavailability) {
      bodyHtml += `
        <h6 class="fw-bold text-danger mt-3">Indisponibilité</h6>
        <p>${unavNotes.length > 0 ? unavNotes : "Indisponible ce jour"}</p>

        <label class="fw-semibold">Modifier la note</label>
        <textarea id="editUnavNotes" class="form-control" rows="2">${unavNotes}</textarea>
      `;
    }

    // --- Jour libre --------------------------------------------------
    if (!hasMissions && !hasUnavailability) {
      bodyHtml += `
        <h6 class="fw-bold text-orange">Ce jour est libre</h6>
        <p class="text-muted small">Ajoutez une mission ou marquez ce jour comme indisponible.</p>
      `;
    }

    modalBody.innerHTML = bodyHtml;

    // ---------------------------------------------------------
    // FOOTER : ACTIONS POSSIBLES
    // ---------------------------------------------------------
    let footer = "";

    // 1 - Ajouter une mission (toujours possible SAUF si indispo)
    if (!hasUnavailability) {
      footer += `
        <a href="/work_sessions/new?date=${date}"
           class="btn btn-orange fw-bold me-auto">
          Ajouter une mission
        </a>
      `;
    }

    // 2 - Ajouter une indispo si jour libre
    if (!hasUnavailability && !hasMissions) {
      footer += `
        <form action="/unavailabilities" method="post">
          <input type="hidden" name="authenticity_token" value="${this.csrf()}">
          <input type="hidden" name="start_date" value="${date}">
          <input type="hidden" name="end_date" value="${date}">
          <button type="submit" class="btn btn-danger">Me rendre indisponible</button>
        </form>
      `;
    }

    // 3 - Modifier une indispo
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

    // 4 - Supprimer une indispo (rendre dispo)
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
    // Synchro notes -> champ hidden (PATCH)
    // ---------------------------------------------------------
    if (hasUnavailability) {
      const form = document.getElementById("editUnavForm");
      form.addEventListener("submit", () => {
        document.getElementById("unav_form_notes").value =
          document.getElementById("editUnavNotes").value;
      });
    }

    // ---------------------------------------------------------
    // OUVRIR LA MODALE (Bootstrap)
    // ---------------------------------------------------------
    const modal = new bootstrap.Modal(document.getElementById("dayModal"));
    modal.show();
  }

  // Format FR pour les dates
  formatDate(dateStr) {
    return new Date(dateStr).toLocaleDateString("fr-FR", {
      weekday: "long",
      day: "numeric",
      month: "long",
    });
  }

  // Récupération du token CSRF
  csrf() {
    return document.querySelector('meta[name="csrf-token"]').content;
  }
}
