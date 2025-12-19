import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["container"];
  static values = {
    key: String,
    recurrence: { type: Number, default: 0 }, // 0 = permanent, sinon nombre de jours
  };

  connect() {
    const storageItem = localStorage.getItem(this.keyValue);

    // 1. Si aucune trace dans le navigateur : on AFFICHE
    if (!storageItem) {
      this.show();
      return;
    }

    // 2. Si c'est une fermeture permanente (Recurrence = 0) : on laisse CACHÉ
    if (this.recurrenceValue === 0) {
      // La classe d-none est déjà là par défaut dans le HTML, on ne fait rien
      return;
    }

    // 3. Si c'est une fermeture temporaire (Recurrence > 0)
    try {
      const data = JSON.parse(storageItem);

      // Sécurité : si le format n'est pas bon (vieux tests), on reset
      if (!data || !data.date) {
        this.resetAndShow();
        return;
      }

      const dismissedAt = new Date(data.date);
      const now = new Date();

      // Calcul du nombre de jours écoulés (en float)
      const diffTime = now - dismissedAt;
      const diffDays = diffTime / (1000 * 60 * 60 * 24);

      if (diffDays >= this.recurrenceValue) {
        // Le délai est passé : on reset et on AFFICHE
        this.resetAndShow();
      } else {
        // Le délai court toujours : on laisse CACHÉ
      }
    } catch (e) {
      // En cas d'erreur de lecture, dans le doute, on AFFICHE
      this.resetAndShow();
    }
  }

  dismiss() {
    // 1. On cache visuellement tout de suite
    this.containerTarget.classList.add("d-none");

    // 2. On enregistre
    if (this.recurrenceValue > 0) {
      // Temporaire : on stocke la date
      const data = { date: new Date().toISOString() };
      localStorage.setItem(this.keyValue, JSON.stringify(data));
    } else {
      // Permanent : on stocke juste "true"
      localStorage.setItem(this.keyValue, "true");
    }
  }

  // --- Helpers ---

  show() {
    this.containerTarget.classList.remove("d-none");
  }

  resetAndShow() {
    localStorage.removeItem(this.keyValue);
    this.show();
  }
}
