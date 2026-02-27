import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";

const REPORT_GROUPS = {
  engagement: [
    "dau_by_mau",
    "daily_engaged_users",
    "likes",
    "bookmarks",
    "user_to_user_likes",
    "time_to_first_response",
    "topics_with_no_response",
  ],
  traffic: [
    "page_views",
    "site_traffic",
    "web_crawlers",
    "mobile_visits",
    "http_4xx_5xx",
    "consolidated_page_views",
  ],
  members: [
    "signups",
    "users_by_trust_level",
    "top_referrers",
    "profile_views",
    "users_by_type",
  ],
  content: ["topics", "posts", "new_contributors", "top_topics", "top_uploads"],
  moderation: [
    "flags",
    "flags_status",
    "staff_logins",
    "moderator_warning_private_messages",
  ],
  security: ["suspicious_logins"],
};

const REPORT_TYPE_TO_GROUP = {};
for (const [group, types] of Object.entries(REPORT_GROUPS)) {
  for (const type of types) {
    REPORT_TYPE_TO_GROUP[type] = group;
  }
}

const GROUP_ORDER = [
  "engagement",
  "traffic",
  "members",
  "content",
  "moderation",
  "security",
  "other",
];

export default class DashboardSidebar extends Component {
  @tracked searchFilter = "";
  @tracked collapsedGroups = new Set();

  get groupedReports() {
    const reports = this.args.availableReports || [];
    const filter = this.searchFilter.toLowerCase().trim();

    const groups = {};
    for (const groupName of GROUP_ORDER) {
      groups[groupName] = [];
    }

    for (const report of reports) {
      if (filter && !report.title?.toLowerCase().includes(filter)) {
        continue;
      }

      const groupName = REPORT_TYPE_TO_GROUP[report.type] || "other";
      if (!groups[groupName]) {
        groups[groupName] = [];
      }
      groups[groupName].push(report);
    }

    const result = [];
    for (const groupName of GROUP_ORDER) {
      const groupReports = groups[groupName];
      if (groupReports && groupReports.length > 0) {
        result.push({
          name: groupName,
          label: i18n(
            `admin.dashboard_v2.sidebar.group_${groupName}`,
            groupName.charAt(0).toUpperCase() + groupName.slice(1)
          ),
          reports: groupReports,
          collapsed: this.collapsedGroups.has(groupName),
        });
      }
    }

    return result;
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

  @action
  addReport(reportType, reportTitle) {
    this.args.onAddPanel("report", reportType, reportTitle);
  }

  <template>
    <div class="custom-dashboard__sidebar">
      <div class="custom-dashboard__sidebar-header">
        <h3 class="custom-dashboard__sidebar-title">
          {{i18n "admin.dashboard_v2.sidebar.title"}}
        </h3>
      </div>

      <input
        class="custom-dashboard__sidebar-search"
        type="text"
        placeholder={{i18n "admin.dashboard_v2.sidebar.search_placeholder"}}
        value={{this.searchFilter}}
        {{on "input" this.onSearch}}
      />

      {{#if @loading}}
        <div class="custom-dashboard__sidebar-loading">
          {{i18n "loading"}}
        </div>
      {{else}}
        <div class="custom-dashboard__sidebar-groups">
          {{#each this.groupedReports as |group|}}
            <div class="custom-dashboard__sidebar-group">
              <button
                class="custom-dashboard__sidebar-group-header btn-flat"
                type="button"
                {{on "click" (fn this.toggleGroup group.name)}}
              >
                <span class="custom-dashboard__sidebar-group-arrow">
                  {{if group.collapsed ">" "v"}}
                </span>
                <span class="custom-dashboard__sidebar-group-label">
                  {{group.label}}
                </span>
                <span class="custom-dashboard__sidebar-group-count">
                  ({{group.reports.length}})
                </span>
              </button>

              {{#unless group.collapsed}}
                <ul class="custom-dashboard__sidebar-items">
                  {{#each group.reports as |report|}}
                    <li class="custom-dashboard__sidebar-item">
                      <button
                        class="custom-dashboard__sidebar-item-btn btn-flat"
                        type="button"
                        {{on
                          "click"
                          (fn this.addReport report.type report.title)
                        }}
                      >
                        {{report.title}}
                      </button>
                    </li>
                  {{/each}}
                </ul>
              {{/unless}}
            </div>
          {{/each}}

          {{! Data Explorer placeholder: shown when query API is available }}
        </div>
      {{/if}}
    </div>
  </template>
}
