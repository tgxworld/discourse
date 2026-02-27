import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class DashboardCard extends Component {
  @tracked loading = true;
  @tracked reportData = null;
  @tracked error = false;

  constructor() {
    super(...arguments);
    this.#fetchData();
  }

  @bind
  refetch() {
    this.#fetchData();
  }

  async #fetchData() {
    this.loading = true;
    this.error = false;
    this.reportData = null;

    try {
      if (this.args.panel.type === "report") {
        const response = await ajax(
          `/admin/reports/${this.args.panel.source}.json`
        );
        this.reportData = response.report;
      } else if (this.args.panel.type === "data_explorer") {
        this.reportData = null;
        this.error = true;
      }
    } catch {
      this.error = true;
    } finally {
      this.loading = false;
    }
  }

  <template>
    <div
      class="custom-dashboard__card-body"
      {{didUpdate this.refetch @panel.source}}
    >
      <ConditionalLoadingSpinner @condition={{this.loading}}>
        {{#if this.error}}
          <div class="custom-dashboard__card-unavailable">
            {{i18n "admin.dashboard_v2.card.unavailable"}}
          </div>
        {{else if this.reportData}}
          <div class="custom-dashboard__card-report">
            {{#if this.reportData.data}}
              <table class="custom-dashboard__card-table">
                <tbody>
                  {{#each this.reportData.data as |row|}}
                    <tr>
                      <td>{{row.x}}</td>
                      <td>{{row.y}}</td>
                    </tr>
                  {{/each}}
                </tbody>
              </table>
            {{else}}
              <span class="custom-dashboard__card-total">
                {{this.reportData.total}}
              </span>
            {{/if}}
          </div>
        {{/if}}
      </ConditionalLoadingSpinner>
    </div>
  </template>
}
