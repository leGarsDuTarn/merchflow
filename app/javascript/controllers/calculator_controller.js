import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "kmInput",
    "kmRow",
    "kmResult",
    "ifm",
    "cp",
    "totalBrut",
    "salaryNet",
    "totalPocket",
  ];

  static values = {
    base: Number,
    ifmRate: Number,
    cpRate: Number,
    kmRate: Number,
    kmLimit: Number,
  };

  connect() {
    // On lance le calcul dès l'affichage de la page
    this.calculate();
  }

  calculate() {
    // 1. Calculs Salaire
    const base = this.baseValue;
    const ifm = base * this.ifmRateValue;
    const subTotal = base + ifm;
    const cp = subTotal * this.cpRateValue;

    const totalBrut = base + ifm + cp;

    // Estimation Net (environ 78% du brut pour les contractuels hors-cadre)
    const netSalary = totalBrut * 0.78;

    // 2. Calculs KM (Net d'impôts)
    let kmAmount = 0;
    if (this.hasKmInputTarget) {
      let km = parseFloat(this.kmInputTarget.value) || 0;

      // Application de la limite si elle existe (et n'est pas illimitée/99999)
      if (
        this.kmLimitValue > 0 &&
        this.kmLimitValue < 99999 &&
        km > this.kmLimitValue
      ) {
        km = this.kmLimitValue;
        // On pourrait ajouter une classe visuelle ici pour dire "Plafonné"
      }

      kmAmount = km * this.kmRateValue;

      // Affichage de la ligne KM uniquement si montant > 0
      if (kmAmount > 0) {
        this.kmRowTarget.classList.remove("d-none");
        this.kmResultTarget.textContent = this.formatMoney(kmAmount);
      } else {
        this.kmRowTarget.classList.add("d-none");
      }
    }

    // 3. Total Poche
    const totalPocket = netSalary + kmAmount;

    // 4. Mise à jour de l'affichage
    this.ifmTarget.textContent = this.formatMoney(ifm);
    this.cpTarget.textContent = this.formatMoney(cp);
    this.totalBrutTarget.textContent = this.formatMoney(totalBrut);
    this.salaryNetTarget.textContent = this.formatMoney(netSalary);
    this.totalPocketTarget.textContent = this.formatMoney(totalPocket);
  }

  formatMoney(amount) {
    return new Intl.NumberFormat("fr-FR", {
      style: "currency",
      currency: "EUR",
    }).format(amount);
  }
}
