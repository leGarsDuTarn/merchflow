import { Application } from "@hotwired/stimulus";

const application = Application.start();
application.debug = false;
window.Stimulus = application;

export { application };

// Bootstrap JS
import * as bootstrap from "bootstrap";
window.bootstrap = bootstrap;

// Tes controllers
import DayController from "./day_controller";
import UnavailabilityController from "./unavailability_controller";

application.register("day", DayController);
application.register("unavailability", UnavailabilityController);
