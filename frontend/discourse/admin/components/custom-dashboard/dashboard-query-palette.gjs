import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

const DASHBOARD_PREFIX = "Dashboard: ";

export default class DashboardQueryPalette extends Component {
  @tracked searchFilter = "";
  @tracked collapsedGroups = new Set();

  get queryGroups() {
    const queries = this.args.availableQueries || [];
    const filter = this.searchFilter.toLowerCase().trim();

    const filtered = filter
      ? queries.filter((q) => q.name?.toLowerCase().includes(filter))
      : queries;

    const dashboard = filtered
      .filter((q) => q.name?.startsWith(DASHBOARD_PREFIX))
      .sort((a, b) => a.name.localeCompare(b.name));

    const other = filtered
      .filter((q) => !q.name?.startsWith(DASHBOARD_PREFIX))
      .sort((a, b) => a.name.localeCompare(b.name));

    const groups = [];
    if (dashboard.length) {
      groups.push({
        name: "dashboard",
        label: i18n("admin.dashboard_v2.sidebar.group_dashboard"),
        queries: dashboard,
        collapsed: this.collapsedGroups.has("dashboard"),
      });
    }
    if (other.length) {
      groups.push({
        name: "other",
        label: i18n("admin.dashboard_v2.sidebar.group_other"),
        queries: other,
        collapsed: this.collapsedGroups.has("other"),
      });
    }
    return groups;
  }

  @action
  toggleGroup(groupName) {
    const next = new Set(this.collapsedGroups);
    if (next.has(groupName)) {
      next.delete(groupName);
    } else {
      next.add(groupName);
    }
    this.collapsedGroups = next;
  }

  @action
  onSearch(event) {
    this.searchFilter = event.target.value;
  }

  <template>
    <div class="dashboard-query-palette">
      <div class="dashboard-query-palette__header">
        <h3 class="dashboard-query-palette__title">
          {{i18n "admin.dashboard_v2.sidebar.title"}}
        </h3>
        {{#if @onShowAi}}
          <DButton
            @action={{@onShowAi}}
            @icon="robot"
            @title={{i18n "admin.dashboard_v2.ai_sidebar.show_ai"}}
            class="btn-flat btn-icon no-text dashboard-query-palette__ai-btn"
          />
        {{/if}}
      </div>

      <input
        class="dashboard-query-palette__search"
        type="text"
        placeholder={{i18n "admin.dashboard_v2.sidebar.search_placeholder"}}
        value={{this.searchFilter}}
        {{on "input" this.onSearch}}
      />

      {{#if @pluginMissing}}
        <div class="dashboard-query-palette__error">
          {{i18n "admin.dashboard_v2.sidebar.plugin_missing"}}
        </div>
      {{else if @loading}}
        <div class="dashboard-query-palette__loading">
          {{i18n "loading"}}
        </div>
      {{else}}
        <div class="dashboard-query-palette__groups">
          {{#each this.queryGroups as |group|}}
            <div class="dashboard-query-palette__group">
              <button
                class="dashboard-query-palette__group-header btn-flat"
                type="button"
                {{on "click" (fn this.toggleGroup group.name)}}
              >
                {{icon (if group.collapsed "angle-right" "angle-down")}}
                <span>{{group.label}}</span>
              </button>

              {{#unless group.collapsed}}
                <ul class="dashboard-query-palette__items">
                  {{#each group.queries as |query|}}
                    <li
                      class="dashboard-query-palette__item"
                      gs-w="3"
                      gs-h="8"
                      data-query-id={{query.id}}
                      data-query-name={{query.name}}
                      title={{query.description}}
                    >
                      <span class="dashboard-query-palette__item-name">
                        {{query.name}}
                      </span>
                      {{icon "grip-lines"}}
                    </li>
                  {{/each}}
                </ul>
              {{/unless}}
            </div>
          {{/each}}
        </div>
      {{/if}}
    </div>
  </template>
}
