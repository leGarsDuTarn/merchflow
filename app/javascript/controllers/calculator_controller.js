import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "kmInput",
    "basePay",
    "ifm",
    "cp",
    "kmResult",
    "kmRow",
    "total",
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
    // 1. Calcul IFM & CP
    const ifm = this.baseValue * this.ifmRateValue;
    const cp = (this.baseValue + ifm) * this.cpRateValue;

    this.ifmTarget.innerText = this.formatCurrency(ifm);
    this.cpTarget.innerText = this.formatCurrency(cp);

    // 2. Calcul KM
    let kmPay = 0;
    if (this.hasKmInputTarget) {
      const kms = parseFloat(this.kmInputTarget.value) || 0;
      const effectiveKms = Math.min(kms, this.kmLimitValue || 9999);
      kmPay = effectiveKms * this.kmRateValue;

      if (kms > 0) {
        this.kmRowTarget.classList.remove("d-none");
        this.kmResultTarget.innerText = "+ " + this.formatCurrency(kmPay);
      } else {
        this.kmRowTarget.classList.add("d-none");
      }
    }

    // 3. Total Final
    const total = this.baseValue + ifm + cp + kmPay;
    this.totalTarget.innerText = this.formatCurrency(total);
  }

  formatCurrency(value) {
    return new Intl.NumberFormat("fr-FR", {
      style: "currency",
      currency: "EUR",
    }).format(value);
  }
}
