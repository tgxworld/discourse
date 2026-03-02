import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import Chart from "discourse/admin/components/chart";
import { i18n } from "discourse-i18n";

function getCSSColor(varName) {
  return getComputedStyle(document.documentElement)
    .getPropertyValue(varName)
    .trim();
}

export default class DashboardChartPreview extends Component {
  get chartConfig() {
    const { columns, rows, chart_type } = this.args.chartData;
    if (!columns || !rows) {
      return null;
    }

    const labels = rows.map((r) => r[0]);
    const data = rows.map((r) =>
      typeof r[1] === "number" ? r[1] : parseFloat(r[1])
    );

    if (chart_type === "pie") {
      return this.#pieConfig(labels, data);
    }
    if (chart_type === "bar") {
      return this.#barConfig(labels, data);
    }
    return this.#lineConfig(labels, data, chart_type === "area");
  }

  get isTable() {
    return this.args.chartData?.chart_type === "table";
  }

  #lineConfig(labels, data, fill) {
    return {
      type: "line",
      data: {
        labels,
        datasets: [
          {
            data,
            borderColor: getCSSColor("--tertiary"),
            backgroundColor: fill
              ? getCSSColor("--tertiary-low")
              : "transparent",
            pointRadius: 0,
            borderWidth: 1.5,
            tension: 0.4,
            fill,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        animation: { duration: 300 },
        plugins: { legend: { display: false } },
        scales: {
          y: {
            beginAtZero: true,
            grid: { color: getCSSColor("--primary-very-low") },
          },
          x: { grid: { display: false } },
        },
      },
    };
  }

  #barConfig(labels, data) {
    return {
      type: "bar",
      data: {
        labels,
        datasets: [
          {
            data,
            backgroundColor: getCSSColor("--tertiary"),
            borderRadius: 4,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        animation: { duration: 300 },
        plugins: { legend: { display: false } },
        scales: {
          y: {
            beginAtZero: true,
            grid: { color: getCSSColor("--primary-very-low") },
          },
          x: { grid: { display: false } },
        },
      },
    };
  }

  #pieConfig(labels, data) {
    const colors = [
      getCSSColor("--tertiary"),
      getCSSColor("--success"),
      getCSSColor("--highlight"),
      getCSSColor("--danger"),
      getCSSColor("--love"),
      getCSSColor("--primary-medium"),
    ];
    return {
      type: "pie",
      data: {
        labels,
        datasets: [
          {
            data,
            backgroundColor: labels.map((_, i) => colors[i % colors.length]),
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        animation: { duration: 300 },
        plugins: {
          legend: {
            position: "bottom",
            labels: { font: { size: 10 } },
          },
        },
      },
    };
  }

  <template>
    <div class="dashboard-chart-preview">
      <div class="dashboard-chart-preview__title">
        {{@chartData.title}}
      </div>
      {{#if this.isTable}}
        <div class="dashboard-chart-preview__table-wrapper">
          <table class="dashboard-chart-preview__table">
            <thead>
              <tr>
                {{#each @chartData.columns as |col|}}
                  <th>{{col}}</th>
                {{/each}}
              </tr>
            </thead>
            <tbody>
              {{#each @chartData.rows as |row|}}
                <tr>
                  {{#each row as |cell|}}
                    <td>{{cell}}</td>
                  {{/each}}
                </tr>
              {{/each}}
            </tbody>
          </table>
        </div>
      {{else if this.chartConfig}}
        <Chart
          @chartConfig={{this.chartConfig}}
          class="dashboard-chart-preview__chart"
        />
      {{/if}}
      <button
        type="button"
        class="btn btn-small btn-default dashboard-chart-preview__add-btn"
        {{on "click" (fn @onAddToDashboard @chartData)}}
      >
        {{i18n "admin.dashboard_v2.ai_sidebar.add_to_dashboard"}}
      </button>
    </div>
  </template>
}
