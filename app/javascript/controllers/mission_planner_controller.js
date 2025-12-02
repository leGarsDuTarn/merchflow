// app/javascript/controllers/mission_planner_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  // Déclare les cibles du formulaire (les champs que nous allons manipuler)
  static targets = ["dateInput"];

  // Se connecte automatiquement lors du chargement de la modale
  connect() {
    console.log("Mission Planner Controller connecté.");

    // Attacher l'écouteur d'événement Bootstrap à l'élément modal
    // L'élément modal est l'élément qui contient le contrôleur Stimulus
    this.element.addEventListener("show.bs.modal", this.injectDate.bind(this));
  }

  // S'assurer de déconnecter l'écouteur pour éviter les fuites mémoire
  disconnect() {
    this.element.removeEventListener(
      "show.bs.modal",
      this.injectDate.bind(this)
    );
  }

  // Méthode appelée lorsque la modale est sur le point de s'ouvrir
  injectDate(event) {
    // 1. Récupérer le bouton qui a déclenché l'ouverture de la modale (la case du calendrier)
    const buttonTrigger = event.relatedTarget;

    // 2. Récupérer la date depuis l'attribut data-mission-date
    const missionDate = buttonTrigger.dataset.missionDate;

    // 3. Injecter la date dans le champ du formulaire (si la date existe et la cible est présente)
    if (missionDate && this.hasDateInputTarget) {
      this.dateInputTarget.value = missionDate;
      console.log(`Date injectée: ${missionDate}`);
    } else if (missionDate) {
      console.error("Cible dateInput non trouvée dans la modale.");
    }
  }
}
