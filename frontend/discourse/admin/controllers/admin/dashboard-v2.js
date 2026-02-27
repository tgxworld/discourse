import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import CustomDashboard from "discourse/admin/models/custom-dashboard";
import discourseDebounce from "discourse/lib/debounce";

const SAVE_DELAY = 1000;

export default class AdminDashboardV2Controller extends Controller {
  @tracked dashboard = null;
  @tracked loading = false;
  @tracked availableReports = [];

  setupModel(model) {
    this.dashboard = model;
    this.availableReports = model.available_reports || [];
  }

  @action
  saveLayout() {
    discourseDebounce(this, this.#debouncedSave, SAVE_DELAY);
  }

  async #debouncedSave() {
    try {
      await CustomDashboard.save(this.dashboard.data);
    } catch {
      // save failed silently
    }
  }
}
