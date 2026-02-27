import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import { i18n } from "discourse-i18n";
import DashboardCard from "./dashboard-card";

export default class DashboardGrid extends Component {
  sortable = null;

  setupGrid = modifier((element) => {
    this.#initDraggable(element);
    return () => this.sortable?.destroy();
  });

  async #initDraggable(element) {
    try {
      const { Sortable } = await import("@shopify/draggable");

      this.sortable = new Sortable(element, {
        draggable: ".custom-dashboard__card",
        handle: ".custom-dashboard__card-drag-handle",
      });

      this.sortable.on("sortable:stop", () => {
        const cards = element.querySelectorAll(".custom-dashboard__card");
        const updatedPanels = [...this.args.panels];

        cards.forEach((card, index) => {
          const panelId = card.dataset.panelId;
          const panel = updatedPanels.find((p) => p.id === panelId);

          if (panel) {
            panel.gridPos = { ...panel.gridPos, y: index };
          }
        });

        this.args.onUpdateLayout(updatedPanels);
      });
    } catch {
      // Shopify Draggable may not be available in test environments
    }
  }

  gridStyle(panel) {
    const { x, y, w, h } = panel.gridPos;
    return htmlSafe(
      `grid-column: ${x + 1} / span ${w}; grid-row: ${y + 1} / span ${h};`
    );
  }

  <template>
    <div class="custom-dashboard__grid" {{this.setupGrid}}>
      {{#each @panels as |panel|}}
        <div
          class="custom-dashboard__card"
          style={{this.gridStyle panel}}
          data-panel-id={{panel.id}}
        >
          <div class="custom-dashboard__card-header">
            <span class="custom-dashboard__card-drag-handle">&#x2807;</span>
            <span class="custom-dashboard__card-title">{{panel.title}}</span>
            <button
              class="custom-dashboard__card-remove btn-flat"
              type="button"
              {{on "click" (fn @onRemovePanel panel.id)}}
            >
              {{i18n "admin.dashboard_v2.card.remove"}}
            </button>
          </div>
          <div class="custom-dashboard__card-content">
            <DashboardCard @panel={{panel}} />
          </div>
        </div>
      {{/each}}
    </div>
  </template>
}
