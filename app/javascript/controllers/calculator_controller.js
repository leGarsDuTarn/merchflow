import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "kmInput",
    "ifm",
    "cp",
    "kmResult",
    "kmRow",
    "totalBrut", // Nouveau
    "totalNet", // Nouveau
  ];
  static values = {
    base: Number,
    ifmRate: Number,
    cpRate: Number,
    kmRate: Number,
    kmLimit: Number,
  };

  connect() {
    this.calculate();
  }

  calculate() {
    // 1. Calcul des primes (IFM & CP) sur le salaire de base
    const ifm = this.baseValue * this.ifmRateValue;
    const cp = (this.baseValue + ifm) * this.cpRateValue;

    // Salaire Brut Hors Frais
    const salaryBrut = this.baseValue + ifm + cp;

    // 2. Calcul du Net (Salaire Brut - 22% de cotisations)
    // Multiplier par 0.78 revient à retirer 22%
    const salaryNet = salaryBrut * 0.78;

    this.ifmTarget.innerText = this.formatCurrency(ifm);
    this.cpTarget.innerText = this.formatCurrency(cp);

    // 3. Calcul des Indemnités Kilométriques (Non soumises aux cotisations)
    let kmPay = 0;
    if (this.hasKmInputTarget) {
      const kms = parseFloat(this.kmInputTarget.value) || 0;

      // On applique la limite si elle existe et qu'elle n'est pas à 0 (cas illimité)
      const effectiveKms =
        this.kmLimitValue > 0 ? Math.min(kms, this.kmLimitValue) : kms;
      kmPay = effectiveKms * this.kmRateValue;

      if (kms > 0) {
        this.kmRowTarget.classList.remove("d-none");
        this.kmResultTarget.innerText = "+ " + this.formatCurrency(kmPay);
      } else {
        this.kmRowTarget.classList.add("d-none");
      }
    }

    // 4. Totaux Finaux
    // Le Brut Total = (Salaire Brut + Frais)
    // Le Net Total = (Salaire Net + Frais) -> Les frais sont payés "net" directement
    const finalBrut = salaryBrut + kmPay;
    const finalNet = salaryNet + kmPay;

    this.totalBrutTarget.innerText = this.formatCurrency(finalBrut);
    this.totalNetTarget.innerText = this.formatCurrency(finalNet);
  }

  formatCurrency(value) {
    return new Intl.NumberFormat("fr-FR", {
      style: "currency",
      currency: "EUR",
    }).format(value);
  }
}
