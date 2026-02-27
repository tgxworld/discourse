import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import CustomDashboard from "discourse/admin/models/custom-dashboard";
import { ajax } from "discourse/lib/ajax";
import discourseDebounce from "discourse/lib/debounce";
import { i18n } from "discourse-i18n";
import DashboardGrid from "./dashboard-grid";
import DashboardSidebar from "./dashboard-sidebar";

const SAVE_DELAY = 1000;

export default class DashboardV2 extends Component {
  @tracked panels = [];
  @tracked availableReports = [];
  @tracked loading = true;

  constructor() {
    super(...arguments);
    this.panels = this.args.dashboard?.data?.panels || [];
    this.#loadReports();
  }

  async #loadReports() {
    try {
      const response = await ajax("/admin/reports.json");
      this.availableReports = response.reports || [];
    } catch {
      this.availableReports = [];
    } finally {
      this.loading = false;
    }
  }

  @action
  addPanel(type, source, title) {
    const panel = {
      id: Math.random().toString(36).slice(2, 8),
      type,
      source,
      title,
      gridPos: { x: 0, y: 0, w: 8, h: 4 },
    };
    this.panels = [...this.panels, panel];
    this.#save();
  }

  @action
  removePanel(panelId) {
    this.panels = this.panels.filter((p) => p.id !== panelId);
    this.#save();
  }

  @action
  updateLayout(updatedPanels) {
    this.panels = updatedPanels;
    discourseDebounce(this, this.#debouncedSave, SAVE_DELAY);
  }

  #save() {
    const data = { panels: this.panels };
    if (this.args.dashboard) {
      this.args.dashboard.data = data;
    }
    CustomDashboard.save(data);
  }

  #debouncedSave() {
    this.#save();
  }

  <template>
    <div class="custom-dashboard">
      <DashboardSidebar
        @availableReports={{this.availableReports}}
        @loading={{this.loading}}
        @onAddPanel={{this.addPanel}}
      />
      <div class="custom-dashboard__grid-area">
        {{#if this.panels.length}}
          <DashboardGrid
            @panels={{this.panels}}
            @onRemovePanel={{this.removePanel}}
            @onUpdateLayout={{this.updateLayout}}
          />
        {{else}}
          <div class="custom-dashboard__empty-state">
            {{i18n "admin.dashboard_v2.empty_state"}}
          </div>
        {{/if}}
      </div>
    </div>
  </template>
}
