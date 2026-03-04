import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import Chart from "discourse/admin/components/chart";
import icon from "discourse/helpers/d-icon";

function getCSSColor(varName) {
  return getComputedStyle(document.documentElement)
    .getPropertyValue(varName)
    .trim();
}

const DATASET_COLORS = [
  "--tertiary",
  "--success",
  "--highlight",
  "--danger",
  "--love",
  "--primary-medium",
];

export default class DataExplorerChartBlock extends Component {
  @tracked expanded = false;
  @tracked copied = false;
  @tracked chartLoading = true;

  detectChartReady = modifier((element) => {
    const canvas = element.querySelector("canvas");
    if (!canvas) {
      this.chartLoading = false;
      return;
    }

    const observer = new MutationObserver(() => {
      if (canvas.getAttribute("width")) {
        this.chartLoading = false;
        observer.disconnect();
      }
    });
    observer.observe(canvas, {
      attributes: true,
      attributeFilter: ["width"],
    });

    const timer = setTimeout(() => {
      this.chartLoading = false;
      observer.disconnect();
    }, 5000);

    return () => {
      observer.disconnect();
      clearTimeout(timer);
    };
  });

  get config() {
    return this.args.chartConfig;
  }

  get datasets() {
    if (this.config?.datasets) {
      return this.config.datasets;
    }
    if (this.config?.rows) {
      return [
        {
          label: this.config.title,
          style: "solid",
          columns: this.config.columns,
          rows: this.config.rows,
        },
      ];
    }
    return [];
  }

  get chartJSConfig() {
    const { chart_type } = this.config;
    const datasets = this.datasets;
    if (datasets.length === 0 || datasets[0].rows?.length === 0) {
      return null;
    }

    if (chart_type === "pie") {
      return this.#pieConfig(datasets[0]);
    }

    const labels = datasets[0].rows.map((r) => r[0]);
    const chartDatasets = datasets.map((ds, idx) => {
      const color = getCSSColor(DATASET_COLORS[idx % DATASET_COLORS.length]);
      const values = ds.rows.map((r) =>
        typeof r[1] === "number" ? r[1] : parseFloat(r[1])
      );

      const base = {
        label: ds.label,
        data: values,
        borderColor: color,
        backgroundColor: color,
      };

      if (chart_type === "bar") {
        return { ...base, borderRadius: 4 };
      }

      const fill = chart_type === "area" && idx === 0;
      return {
        ...base,
        backgroundColor: fill ? getCSSColor("--tertiary-low") : "transparent",
        pointRadius: 3,
        borderWidth: ds.style === "dashed" ? 2 : 1.5,
        borderDash: ds.style === "dashed" ? [6, 4] : [],
        tension: 0.4,
        fill,
      };
    });

    const dataLength = datasets[0].rows.length;
    const isLine = chart_type === "line" || chart_type === "area";

    return {
      type: isLine ? "line" : chart_type,
      data: { labels, datasets: chartDatasets },
      options: this.#chartOptions(datasets.length > 1, isLine, dataLength),
    };
  }

  @action
  toggleExpanded(e) {
    e.stopPropagation();
    this.expanded = !this.expanded;
  }

  @action
  async copyQuery(e) {
    e.stopPropagation();
    await navigator.clipboard.writeText(this.config?.sql || "");
    this.copied = true;
    setTimeout(() => (this.copied = false), 2000);
  }

  #pieConfig(dataset) {
    const labels = dataset.rows.map((r) => r[0]);
    const data = dataset.rows.map((r) =>
      typeof r[1] === "number" ? r[1] : parseFloat(r[1])
    );
    const colors = DATASET_COLORS.map((v) => getCSSColor(v));

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
        maintainAspectRatio: false,
        animation: { duration: 300 },
        plugins: {
          legend: { position: "bottom", labels: { font: { size: 10 } } },
        },
      },
    };
  }

  #chartOptions(showLegend, progressive, dataLength) {
    const options = {
      responsive: true,
      maintainAspectRatio: false,
      interaction: { intersect: false, mode: "index" },
      plugins: {
        legend: showLegend
          ? { position: "bottom", labels: { font: { size: 11 } } }
          : { display: false },
      },
      scales: {
        y: {
          beginAtZero: true,
          grid: { color: getCSSColor("--primary-very-low") },
        },
        x: { grid: { display: false } },
      },
    };

    if (progressive && dataLength > 1) {
      const totalDuration = 1200;
      const delay = totalDuration / dataLength;

      options.transitions = {
        active: { animation: { duration: 0 } },
      };
      options.animations = {
        x: {
          type: "number",
          easing: "linear",
          duration: delay,
          from: NaN,
          delay: (ctx) => (ctx.type === "data" ? ctx.index * delay : 0),
        },
        y: {
          type: "number",
          easing: "easeOutQuart",
          duration: delay,
          from: (ctx) => {
            if (ctx.type !== "data" || ctx.index === 0) {
              return ctx.chart.scales.y.getPixelForValue(0);
            }
            return ctx.chart
              .getDatasetMeta(ctx.datasetIndex)
              .data[ctx.index - 1].getProps(["y"], true).y;
          },
          delay: (ctx) => (ctx.type === "data" ? ctx.index * delay : 0),
        },
      };
    } else {
      options.animation = { duration: 600, easing: "easeOutQuart" };
    }

    return options;
  }

  <template>
    <div class="data-explorer-chart-block">
      {{#if this.config.sql}}
        <div
          class="data-explorer-chart-block__query
            {{if this.expanded 'is-expanded'}}"
        >
          <div
            class="data-explorer-chart-block__query-code"
          >{{this.config.sql}}</div>
          {{#if this.expanded}}
            <button
              type="button"
              class="btn btn-flat btn-small data-explorer-chart-block__copy-btn"
              {{on "click" this.copyQuery}}
            >
              {{#if this.copied}}
                {{icon "check"}}
              {{else}}
                {{icon "copy"}}
              {{/if}}
            </button>
          {{else}}
            <div
              class="data-explorer-chart-block__query-fade"
              role="button"
              {{on "click" this.toggleExpanded}}
            ></div>
          {{/if}}
        </div>
      {{/if}}

      <div class="data-explorer-chart-block__result">
        {{#if this.config.title}}
          <div class="data-explorer-chart-block__title">
            {{this.config.title}}
          </div>
        {{/if}}

        {{#if this.chartJSConfig}}
          <div
            class="data-explorer-chart-block__chart"
            {{this.detectChartReady}}
          >
            {{#if this.chartLoading}}
              <div class="data-explorer-chart-block__loading">
                <div class="spinner small"></div>
              </div>
            {{/if}}
            <Chart @chartConfig={{this.chartJSConfig}} />
          </div>
        {{/if}}
      </div>
    </div>
  </template>
}
