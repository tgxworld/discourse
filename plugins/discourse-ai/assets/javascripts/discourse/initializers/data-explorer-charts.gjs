import { withPluginApi } from "discourse/lib/plugin-api";
import DataExplorerChartBlock from "../components/data-explorer-chart-block";

function initializeDataExplorerCharts(api) {
  api.decorateCookedElement(
    (element, helper) => {
      if (!helper.renderGlimmer) {
        return;
      }

      [...element.querySelectorAll("div.data-explorer-chart")].forEach(
        (chartElement) => {
          const configAttr = chartElement.getAttribute("data-chart-config");
          if (!configAttr) {
            return;
          }

          let chartConfig;
          try {
            const decoded = new DOMParser().parseFromString(
              configAttr,
              "text/html"
            ).documentElement.textContent;
            chartConfig = JSON.parse(decoded);
          } catch {
            return;
          }

          helper.renderGlimmer(
            chartElement,
            <template>
              <DataExplorerChartBlock @chartConfig={{chartConfig}} />
            </template>
          );
        }
      );
    },
    {
      id: "data-explorer-chart",
      onlyStream: true,
    }
  );
}

export default {
  name: "data-explorer-charts",
  initialize() {
    withPluginApi(initializeDataExplorerCharts);
  },
};
