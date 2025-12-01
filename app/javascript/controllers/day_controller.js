import { Controller } from "@hotwired/stimulus";

// Controller principal pour la modale
export default class extends Controller {
  // 🔥 Ajout : cible pour le focus "aujourd’hui"
  static targets = ["todayAnchor"];

  // 🔥 Ajout : auto-scroll vers la cellule "today" sur mobile
  connect() {
    const todayCell = document.querySelector(".calendar-cell.today");
    if (todayCell) {
      todayCell.scrollIntoView({
        behavior: "smooth",
        block: "center",
        inline: "center",
      });
    }
  }

  // =========================================================
  // 🔥 Bouton mobile : "Ajouter une mission"
  // =========================================================
  openNewMission() {
    const today = new Date().toISOString().split("T")[0];
    window.location.href = `/work_sessions/new?date=${today}`;
  }

  // =========================================================
  // 🔥 Bouton mobile : "Ajouter une indisponibilité"
  // =========================================================
  openNewUnavailability() {
    // On pré-remplit avec la date d'aujourd'hui pour le confort
    const today = new Date().toISOString().split("T")[0];

    const modalTitle = document.getElementById("dayModalTitle");
    const modalBody = document.getElementById("dayModalBody");
    const modalFooter = document.getElementById("dayModalFooter");

    // Titre générique puisqu'on peut choisir la date
    modalTitle.innerHTML = `Nouvelle indisponibilité`;

    // CORPS : On ajoute un input TYPE DATE + le Textarea
    modalBody.innerHTML = `
      <div class="mb-3">
        <label class="fw-semibold mb-1">Date concernée</label>
        <input type="date" id="newUnavDateSelect" class="form-control" value="${today}">
      </div>

      <div class="mb-1">
        <label class="fw-semibold mb-1">Motif (optionnel)</label>
        <textarea id="newUnavNotes" class="form-control" rows="2"
          placeholder="Ex : RDV, CP, repos…"></textarea>
      </div>
    `;

    // FOOTER : Le formulaire avec des inputs hidden qui recevront les valeurs
    modalFooter.innerHTML = `
      <form action="/unavailabilities" method="post" id="newUnavForm">
        <input type="hidden" name="authenticity_token" value="${this.csrf()}">

        <input type="hidden" name="date" id="new_unav_form_date">
        <input type="hidden" name="notes" id="new_unav_form_notes">

        <button type="submit" class="btn btn-red w-100 fw-bold">
          Confirmer l'indisponibilité
        </button>
      </form>
    `;

    const modalElement = document.getElementById("dayModal");
    const modal = new bootstrap.Modal(modalElement);
    modal.show();

    // LISTENER : Au moment de valider, on copie la date choisie et la note dans le form
    setTimeout(() => {
      const newForm = document.getElementById("newUnavForm");
      if (newForm) {
        newForm.addEventListener("submit", (e) => {
          // 1. Récupérer la date choisie par l'utilisateur
          const dateValue = document.getElementById("newUnavDateSelect").value;
          // 2. Récupérer la note
          const noteValue = document.getElementById("newUnavNotes").value;

          // 3. Si l'utilisateur n'a pas mis de date (peu probable avec un input date), on bloque ou on met today par défaut
          if (!dateValue) {
             e.preventDefault();
             alert("Veuillez sélectionner une date.");
             return;
          }

          // 4. Injecter dans les champs cachés du formulaire
          document.getElementById("new_unav_form_date").value = dateValue;
          document.getElementById("new_unav_form_notes").value = noteValue;
        });
      }
    }, 100);
  }

  // =========================================================
  // CLIC SUR UNE CELLULE DU CALENDRIER
  // =========================================================
  open(event) {
    const cell = event.currentTarget;

    // Récupération des données depuis les attributs data-* du HTML
    const date = cell.dataset.date;
    const missions = JSON.parse(cell.dataset.missions || "[]");
    const hasMissions = cell.dataset.hasMissions === "true";
    const hasUnavailability = cell.dataset.hasUnavailability === "true";
    const unavId = cell.dataset.unavailabilityId;
    const unavNotes = cell.dataset.unavailabilityNotes || "";

    // Cibles du DOM dans la modale
    const modalTitle = document.getElementById("dayModalTitle");
    const modalBody = document.getElementById("dayModalBody");
    const modalFooter = document.getElementById("dayModalFooter");

    // ---------------------------------------------------------
    // 1. LE TITRE
    // ---------------------------------------------------------
    modalTitle.innerHTML = `Actions du ${this.formatDate(date)}`;

    // ---------------------------------------------------------
    // 2. LE CORPS DE LA MODALE
    // ---------------------------------------------------------
    let bodyHtml = "";

    // CAS A : Il y a des missions
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

    // CAS B : Il y a une indisponibilité
    if (hasUnavailability) {
      bodyHtml += `
        <h6 class="fw-bold text-danger mt-3">Indisponible</h6>
        <p><strong>Motif :</strong>${unavNotes ? " " + unavNotes : " Aucun"}</p>

        <label class="fw-semibold mt-2">Modifier la note</label>
        <textarea id="editUnavNotes" class="form-control" rows="2">${unavNotes}</textarea>
      `;
    }

    // CAS C : Jour totalement libre
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
    // 3. LE FOOTER (ACTIONS)
    // ---------------------------------------------------------
    let footer = "";

    // Bouton : Ajouter mission (sauf si déjà indisponible)
    if (!hasUnavailability) {
      footer += `
        <a href="/work_sessions/new?date=${date}"
           class="btn btn-orange fw-bold me-auto">
          Ajouter une mission
        </a>
      `;
    }

    // Bouton : Créer l'indisponibilité (si libre)
    if (!hasUnavailability && !hasMissions) {
      footer += `
        <form action="/unavailabilities" method="post" id="newUnavForm">
          <input type="hidden" name="authenticity_token" value="${this.csrf()}">
          <input type="hidden" name="date" value="${date}">
          <input type="hidden" name="notes" id="new_unav_form_notes">
          <button type="submit" class="btn btn-red">Me rendre indisponible</button>
        </form>
      `;
    }

    // Bouton : Mettre à jour l'indispo existante
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

    // Bouton : Supprimer l'indispo
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
    // 4. LISTENERS POUR NOTES
    // ---------------------------------------------------------
    const modalElement = document.getElementById("dayModal");
    const modal = new bootstrap.Modal(modalElement);
    modal.show();

    setTimeout(() => {
      // Création
      const newForm = document.getElementById("newUnavForm");
      if (newForm) {
        newForm.addEventListener("submit", () => {
          const noteValue = document.getElementById("newUnavNotes").value;
          document.getElementById("new_unav_form_notes").value = noteValue;
        });
      }

      // Edition
      const editForm = document.getElementById("editUnavForm");
      if (editForm) {
        editForm.addEventListener("submit", () => {
          const noteValue = document.getElementById("editUnavNotes").value;
          document.getElementById("unav_form_notes").value = noteValue;
        });
      }
    }, 100);
  }

  // Formatage FR
  formatDate(dateStr) {
    if (!dateStr) return "";
    return new Date(dateStr).toLocaleDateString("fr-FR", {
      weekday: "long",
      day: "numeric",
      month: "long",
    });
  }

  // Token CSRF Rails
  csrf() {
    const token = document.querySelector("meta[name='csrf-token']");
    return token ? token.content : "";
  }
}
