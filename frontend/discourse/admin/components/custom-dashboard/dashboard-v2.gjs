import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import CustomDashboard from "discourse/admin/models/custom-dashboard";
import DateTimeInputRange from "discourse/components/date-time-input-range";
import DMenu from "discourse/float-kit/components/d-menu";
import { ajax } from "discourse/lib/ajax";
import discourseDebounce from "discourse/lib/debounce";
import eq from "discourse/truth-helpers/helpers/eq";
import { i18n } from "discourse-i18n";
import DashboardGrid from "./dashboard-grid";
import DashboardQueryPalette from "./dashboard-query-palette";

const SAVE_DELAY = 1000;

const PRESETS = [
  { key: "7", label: "7d" },
  { key: "14", label: "14d" },
  { key: "30", label: "30d" },
];

function formatDate(date) {
  return date.toISOString().split("T")[0];
}

function daysAgo(n) {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return formatDate(d);
}

export default class DashboardV2 extends Component {
  @tracked panels = [];
  @tracked availableQueries = [];
  @tracked loading = true;
  @tracked pluginMissing = false;
  @tracked activePreset = "7";
  @tracked customFrom = null;
  @tracked customTo = null;
  findTargets = modifier(() => {
    this._sidebarElement = document.querySelector(".sidebar-wrapper");
    this._headerElement = document.querySelector(".d-page-header__description");
  });
  @tracked _sidebarElement = null;
  @tracked _headerElement = null;

  constructor() {
    super(...arguments);
    this.panels = this.args.dashboard?.data?.panels || [];
    this.#loadQueries();
  }

  get presets() {
    return PRESETS;
  }

  get startDate() {
    if (this.activePreset === "custom" && this.customFrom) {
      return this.customFrom.format("YYYY-MM-DD");
    }
    return daysAgo(parseInt(this.activePreset, 10));
  }

  get endDate() {
    if (this.activePreset === "custom" && this.customTo) {
      return this.customTo.format("YYYY-MM-DD");
    }
    return formatDate(new Date());
  }

  get isCustom() {
    return this.activePreset === "custom";
  }

  async #loadQueries() {
    try {
      const response = await ajax("/admin/plugins/explorer/queries.json");
      const queries = response.queries || [];
      const seen = new Set();
      this.availableQueries = queries.filter((q) => {
        if (seen.has(q.id)) {
          return false;
        }
        seen.add(q.id);
        return true;
      });
    } catch {
      this.availableQueries = [];
      this.pluginMissing = true;
    } finally {
      this.loading = false;
    }
  }

  @action
  selectPreset(key) {
    this.activePreset = key;
  }

  @action
  onDateMenuShow() {
    if (this.activePreset !== "custom") {
      const days = parseInt(this.activePreset, 10);
      this.customFrom = moment().subtract(days, "days");
      this.customTo = moment();
    }
    this.activePreset = "custom";
  }

  @action
  onCustomDateChange({ from, to }) {
    this.customFrom = from;
    this.customTo = to;
  }

  @action
  addPanel(type, source, title, gridPos) {
    const panel = {
      id: Math.random().toString(36).slice(2, 8),
      type,
      source,
      title,
      gridPos: gridPos || { x: 0, y: 0, w: 3, h: 8 },
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
    <div class="custom-dashboard" {{this.findTargets}}>
      {{#if this._sidebarElement}}
        {{#in-element this._sidebarElement insertBefore=null}}
          <DashboardQueryPalette
            @availableQueries={{this.availableQueries}}
            @loading={{this.loading}}
            @pluginMissing={{this.pluginMissing}}
          />
        {{/in-element}}
      {{/if}}

      {{#if this._headerElement}}
        {{#in-element this._headerElement insertBefore=null}}
          <div class="custom-dashboard__toolbar">
            <div class="custom-dashboard__date-range">
              {{#each this.presets as |preset|}}
                <button
                  class="btn btn-small custom-dashboard__date-btn
                    {{if
                      (eq this.activePreset preset.key)
                      'btn-primary'
                      'btn-default'
                    }}"
                  type="button"
                  {{on "click" (fn this.selectPreset preset.key)}}
                >
                  {{preset.label}}
                </button>
              {{/each}}
              <DMenu
                @identifier="custom-date-range"
                @arrow={{false}}
                @onShow={{this.onDateMenuShow}}
                @triggerClass={{if
                  this.isCustom
                  "btn btn-small btn-primary custom-dashboard__date-btn"
                  "btn btn-small btn-default custom-dashboard__date-btn"
                }}
                @label={{i18n "admin.dashboard_v2.date_range.custom"}}
              >
                <:content>
                  <div class="custom-dashboard__date-picker-panel">
                    <DateTimeInputRange
                      @from={{this.customFrom}}
                      @to={{this.customTo}}
                      @onChange={{this.onCustomDateChange}}
                      @showFromTime={{false}}
                      @showToTime={{false}}
                    />
                  </div>
                </:content>
              </DMenu>
            </div>
          </div>
        {{/in-element}}
      {{/if}}

      <DashboardGrid
        @panels={{this.panels}}
        @startDate={{this.startDate}}
        @endDate={{this.endDate}}
        @onRemovePanel={{this.removePanel}}
        @onUpdateLayout={{this.updateLayout}}
        @onAddPanel={{this.addPanel}}
      />
    </div>
  </template>
}
