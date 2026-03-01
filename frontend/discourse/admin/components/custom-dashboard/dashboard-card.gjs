import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import Chart from "discourse/admin/components/chart";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

function getCSSColor(varName) {
  return getComputedStyle(document.documentElement)
    .getPropertyValue(varName)
    .trim();
}

function formatDate(date) {
  return date.toISOString().split("T")[0];
}

function isDateString(value) {
  if (typeof value !== "string") {
    return false;
  }
  return /^\d{4}-\d{2}-\d{2}/.test(value) && !isNaN(Date.parse(value));
}

function isNumeric(value) {
  if (typeof value === "number") {
    return true;
  }
  if (typeof value === "string") {
    return value.trim() !== "" && !isNaN(Number(value));
  }
  return false;
}

export default class DashboardCard extends Component {
  @tracked loading = true;
  @tracked columns = null;
  @tracked rows = null;
  @tracked error = false;

  constructor() {
    super(...arguments);
    this.#fetchData();
  }

  @bind
  refetch() {
    this.#fetchData();
  }

  get hasData() {
    return this.columns?.length > 0 && this.rows?.length > 0;
  }

  get isTimeSeries() {
    if (
      !this.columns ||
      !this.rows ||
      this.rows.length < 2 ||
      this.columns.length < 2
    ) {
      return false;
    }
    const sample = this.rows.slice(0, Math.min(5, this.rows.length));
    return (
      sample.every((r) => isDateString(r[0])) &&
      sample.every((r) => isNumeric(r[1]))
    );
  }

  get chartConfig() {
    const labels = this.rows.map((r) => r[0]);
    const data = this.rows.map((r) =>
      typeof r[1] === "number" ? r[1] : parseFloat(r[1])
    );

    return {
      type: "line",
      data: {
        labels,
        datasets: [
          {
            data,
            label: this.columns[1],
            borderColor: getCSSColor("--tertiary"),
            backgroundColor: "transparent",
            pointRadius: 0,
            pointHoverRadius: 4,
            pointBackgroundColor: getCSSColor("--tertiary"),
            borderWidth: 1.5,
            tension: 0.4,
            fill: false,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: { duration: 300 },
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: getCSSColor("--primary"),
            cornerRadius: 8,
            padding: { left: 12, right: 12, top: 8, bottom: 8 },
            mode: "index",
            intersect: false,
          },
        },
        scales: {
          y: {
            beginAtZero: true,
            suggestedMax: 1,
            grid: { color: getCSSColor("--primary-very-low") },
            border: { display: false },
            ticks: {
              precision: 0,
              maxTicksLimit: 4,
              font: { size: 10 },
              color: getCSSColor("--primary-medium"),
            },
          },
          x: {
            grid: { display: false },
            type: "time",
            time: { unit: "day" },
            ticks: {
              maxTicksLimit: 4,
              font: { size: 10 },
              color: getCSSColor("--primary-medium"),
            },
            border: { display: false },
          },
        },
      },
    };
  }

  async #fetchData() {
    this.loading = true;
    this.error = false;
    this.columns = null;
    this.rows = null;

    try {
      const params = {
        start_date: this.args.startDate || formatDate(new Date()),
        end_date: this.args.endDate || formatDate(new Date()),
      };

      const response = await ajax(
        `/admin/plugins/explorer/queries/${this.args.panel.source}/run`,
        { type: "POST", data: { params: JSON.stringify(params) } }
      );
      this.columns = response.columns || [];
      this.rows = response.rows || [];
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
      {{didUpdate this.refetch @startDate}}
      {{didUpdate this.refetch @endDate}}
    >
      <ConditionalLoadingSpinner @condition={{this.loading}}>
        {{#if this.error}}
          <div class="custom-dashboard__card-unavailable">
            {{i18n "admin.dashboard_v2.card.unavailable"}}
          </div>
        {{else if this.hasData}}
          {{#if this.isTimeSeries}}
            <Chart
              @chartConfig={{this.chartConfig}}
              class="custom-dashboard__card-chart"
            />
          {{else}}
            <div class="custom-dashboard__card-table-wrapper">
              <table class="custom-dashboard__card-table">
                <thead>
                  <tr>
                    {{#each this.columns as |col|}}
                      <th>{{col}}</th>
                    {{/each}}
                  </tr>
                </thead>
                <tbody>
                  {{#each this.rows as |row|}}
                    <tr>
                      {{#each row as |cell|}}
                        <td>{{cell}}</td>
                      {{/each}}
                    </tr>
                  {{/each}}
                </tbody>
              </table>
            </div>
          {{/if}}
        {{else}}
          <div class="custom-dashboard__card-empty">
            {{i18n "admin.dashboard_v2.card.no_data"}}
          </div>
        {{/if}}
      </ConditionalLoadingSpinner>
    </div>
  </template>
}
