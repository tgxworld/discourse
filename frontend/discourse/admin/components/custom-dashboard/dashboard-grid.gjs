import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import icon from "discourse/helpers/d-icon";
import loadGridstack from "discourse/lib/load-gridstack";
import eq from "discourse/truth-helpers/helpers/eq";
import { i18n } from "discourse-i18n";
import DashboardCard from "./dashboard-card";
import DashboardCardEditor from "./dashboard-card-editor";

const focusInput = modifier((element) => {
  element.focus();
  element.select();
});

const GRID_COLS = 6;
const CELL_HEIGHT = 45;
const DEFAULT_CARD_W = 3;
const DEFAULT_CARD_H = 8;
const MIN_CARD_W = 2;
const MIN_CARD_H = 4;
const MARGIN = 16;

export default class DashboardGrid extends Component {
  @service modal;

  gridstackInit = modifier((element) => {
    this._initGridstack(element);
    return () => this._destroyGridstack();
  });

  syncStatic = modifier(() => {
    const customizing = this.args.customizing;

    // Consume _isLoading so this modifier re-runs when grid init completes.
    // Without this, _grid is null on first run, customizing is never read,
    // and the modifier never re-triggers.
    if (this._isLoading || !this._grid) {
      return;
    }

    this._grid.setStatic(!customizing);
    if (customizing) {
      requestAnimationFrame(() => this._setupPaletteDragIn());
    }
  });

  registerWidget = modifier((element) => {
    if (this._grid && !element.gridstackNode) {
      this._enterBatch();
      this._grid.makeWidget(element);
      this._leaveBatch();
    }
    return () => {
      if (this._grid && element.gridstackNode) {
        this._enterBatch();
        this._grid.removeWidget(element, false, false);
        this._leaveBatch();
      }
    };
  });

  @tracked _editingTitlePanelId = null;
  @tracked _editingTitleValue = "";
  @tracked _isLoading = true;

  _grid = null;
  _GridStack = null;
  _paletteObserver = null;
  _placeholderWatcher = null;
  _ignoreChange = false;
  _batchDepth = 0;
  _gridElement = null;
  _cellContainer = null;
  _highlightedCells = [];
  _lastHighlightKey = null;

  _buildCellContainer() {
    if (this._cellContainer) {
      return;
    }
    const container = document.createElement("div");
    container.className = "custom-dashboard__grid-cells";
    this._gridElement.insertBefore(container, this._gridElement.firstChild);
    this._cellContainer = container;

    let maxRow = 0;
    for (const panel of this.args.panels || []) {
      const bottom = panel.gridPos.y + panel.gridPos.h;
      if (bottom > maxRow) {
        maxRow = bottom;
      }
    }
    const scrollRows = Math.ceil(this._gridElement.scrollHeight / CELL_HEIGHT);
    const totalRows = Math.max(
      maxRow + DEFAULT_CARD_H * 2,
      scrollRows + DEFAULT_CARD_H,
      24
    );
    const colWidth = 100 / GRID_COLS;

    for (let row = 0; row < totalRows; row++) {
      for (let col = 0; col < GRID_COLS; col++) {
        const cell = document.createElement("div");
        cell.className = "custom-dashboard__grid-cell";
        cell.style.cssText = `left:${col * colWidth}%;top:${row * CELL_HEIGHT}px;width:${colWidth}%;height:${CELL_HEIGHT}px;`;
        cell.dataset.col = col;
        cell.dataset.row = row;
        container.appendChild(cell);
      }
    }
    container.style.height = `${totalRows * CELL_HEIGHT}px`;
  }

  _showCells() {
    this._buildCellContainer();
    this._cellContainer.classList.add("is-active");
  }

  _updateHighlight(node) {
    if (!this._cellContainer) {
      return;
    }
    for (const cell of this._highlightedCells) {
      cell.classList.remove(
        "is-highlighted",
        "is-top",
        "is-bottom",
        "is-left",
        "is-right"
      );
    }
    this._highlightedCells = [];

    const cells = this._cellContainer.children;
    for (let row = node.y; row < node.y + node.h; row++) {
      for (let col = node.x; col < node.x + node.w; col++) {
        const el = cells[row * GRID_COLS + col];
        if (el) {
          el.classList.add("is-highlighted");
          if (row === node.y) {
            el.classList.add("is-top");
          }
          if (row === node.y + node.h - 1) {
            el.classList.add("is-bottom");
          }
          if (col === node.x) {
            el.classList.add("is-left");
          }
          if (col === node.x + node.w - 1) {
            el.classList.add("is-right");
          }
          this._highlightedCells.push(el);
        }
      }
    }
  }

  _hideCells() {
    for (const cell of this._highlightedCells) {
      cell.classList.remove(
        "is-highlighted",
        "is-top",
        "is-bottom",
        "is-left",
        "is-right"
      );
    }
    this._highlightedCells = [];
    if (this._cellContainer) {
      this._cellContainer.classList.remove("is-active");
    }
  }

  _teardownCells() {
    this._highlightedCells = [];
    if (this._cellContainer) {
      this._cellContainer.remove();
      this._cellContainer = null;
    }
  }

  async _initGridstack(element) {
    const { GridStack } = await loadGridstack();

    if (!element.isConnected) {
      return;
    }

    this._GridStack = GridStack;
    this._gridElement = element;

    this._grid = GridStack.init(
      {
        column: GRID_COLS,
        cellHeight: CELL_HEIGHT,
        margin: MARGIN,
        float: false,
        animate: true,
        staticGrid: !this.args.customizing,
        resizable: { handles: "se" },
        draggable: { handle: ".custom-dashboard__card-drag-handle" },
        minRow: 1,
        acceptWidgets: ".dashboard-query-palette__item",
      },
      element
    );

    // Register any widgets already rendered by Ember before gridstack init finished
    this._ignoreChange = true;
    element
      .querySelectorAll(".grid-stack-item.custom-dashboard__card")
      .forEach((el) => {
        if (!el.gridstackNode) {
          this._grid.makeWidget(el);
        }
      });
    this._ignoreChange = false;

    this._grid.on("change", (_event, nodes) => {
      if (this._ignoreChange) {
        return;
      }
      this._syncFromGridstack(nodes);
    });

    this._grid.on("dropped", (_event, _previousNode, newNode) => {
      const el = newNode.el;
      if (!el) {
        return;
      }

      const queryId = el.getAttribute("data-query-id");
      const queryName = el.getAttribute("data-query-name");

      if (!queryId) {
        return;
      }

      this._grid.removeWidget(el, true, false);

      const gridPos = {
        x: newNode.x,
        y: newNode.y,
        w: DEFAULT_CARD_W,
        h: DEFAULT_CARD_H,
      };
      this.args.onAddPanel("data_explorer", queryId, queryName, gridPos);
    });

    this._grid.on("dragstart resizestart", () => {
      element.classList.remove("grid-stack-animate");
    });
    this._grid.on("dragstop resizestop", () => {
      element.classList.add("grid-stack-animate");
    });

    this._setupPlaceholderWatch();

    this._setupPaletteDragIn();
    this._isLoading = false;
  }

  _setupPlaceholderWatch() {
    this._placeholderWatcher = new MutationObserver(() => {
      const ph = this._gridElement.querySelector(".grid-stack-placeholder");
      if (!ph) {
        if (this._lastHighlightKey !== null) {
          this._hideCells();
          this._lastHighlightKey = null;
        }
        return;
      }

      const x = parseInt(ph.getAttribute("gs-x"), 10);
      const y = parseInt(ph.getAttribute("gs-y"), 10);
      const w = parseInt(ph.getAttribute("gs-w"), 10);
      const h = parseInt(ph.getAttribute("gs-h"), 10);

      if (isNaN(x) || isNaN(y) || isNaN(w) || isNaN(h)) {
        return;
      }

      const key = `${x},${y},${w},${h}`;
      if (key === this._lastHighlightKey) {
        return;
      }
      this._lastHighlightKey = key;
      this._showCells();
      this._updateHighlight({ x, y, w, h });
    });

    this._placeholderWatcher.observe(this._gridElement, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ["gs-x", "gs-y", "gs-w", "gs-h"],
    });
  }

  _setupPaletteDragIn() {
    const palette = document.querySelector(".dashboard-query-palette");
    if (!palette || !this._GridStack) {
      return;
    }

    this._GridStack.setupDragIn(".dashboard-query-palette__item", {
      helper: "clone",
      appendTo: "body",
    });

    this._paletteObserver = new MutationObserver(() => {
      this._GridStack.setupDragIn(".dashboard-query-palette__item", {
        helper: "clone",
        appendTo: "body",
      });
    });
    this._paletteObserver.observe(palette, { childList: true, subtree: true });
  }

  _enterBatch() {
    this._ignoreChange = true;
    if (this._batchDepth === 0) {
      this._grid.batchUpdate();
    }
    this._batchDepth++;
  }

  _leaveBatch() {
    this._batchDepth--;
    if (this._batchDepth === 0) {
      this._grid.batchUpdate(false);
    }
    this._ignoreChange = this._batchDepth > 0;
  }

  _syncFromGridstack(nodes) {
    const updatedPanels = this.args.panels.map((panel) => {
      const node = nodes.find(
        (n) => n.id === panel.id || n.el?.dataset?.panelId === panel.id
      );
      if (node) {
        return {
          ...panel,
          gridPos: {
            x: node.x,
            y: node.y,
            w: node.w,
            h: node.h,
          },
        };
      }
      return panel;
    });
    this.args.onUpdateLayout(updatedPanels);
  }

  _destroyGridstack() {
    if (this._placeholderWatcher) {
      this._placeholderWatcher.disconnect();
      this._placeholderWatcher = null;
    }
    if (this._paletteObserver) {
      this._paletteObserver.disconnect();
      this._paletteObserver = null;
    }
    this._teardownCells();
    if (this._grid) {
      this._grid.offAll();
      this._grid.destroy(false);
      this._grid = null;
    }
  }

  @action
  startTitleEdit(panelId, currentTitle, event) {
    if (event?.type === "keydown" && event.key !== "Enter") {
      return;
    }
    this._editingTitlePanelId = panelId;
    this._editingTitleValue = currentTitle;
  }

  @action
  onTitleInput(event) {
    this._editingTitleValue = event.target.value;
  }

  @action
  saveTitleEdit(panelId) {
    if (this._editingTitlePanelId === panelId) {
      this.args.onUpdatePanel(panelId, { title: this._editingTitleValue });
      this._editingTitlePanelId = null;
      this._editingTitleValue = "";
    }
  }

  @action
  cancelTitleEdit() {
    this._editingTitlePanelId = null;
    this._editingTitleValue = "";
  }

  @action
  onTitleKeydown(panelId, event) {
    if (event.key === "Enter") {
      event.preventDefault();
      this.saveTitleEdit(panelId);
    } else if (event.key === "Escape") {
      event.preventDefault();
      this.cancelTitleEdit();
    }
  }

  @action
  async editCard(panel) {
    const result = await this.modal.show(DashboardCardEditor, {
      model: { panel },
    });
    if (result?.title !== undefined) {
      this.args.onUpdatePanel(panel.id, { title: result.title });
    }
  }

  <template>
    <div
      class="custom-dashboard__grid grid-stack
        {{if this._isLoading 'is-loading'}}"
      {{this.gridstackInit}}
      {{this.syncStatic}}
    >
      {{#each @panels key="id" as |panel|}}
        <div
          class="grid-stack-item custom-dashboard__card"
          gs-x={{panel.gridPos.x}}
          gs-y={{panel.gridPos.y}}
          gs-w={{panel.gridPos.w}}
          gs-h={{panel.gridPos.h}}
          gs-min-w={{MIN_CARD_W}}
          gs-min-h={{MIN_CARD_H}}
          gs-id={{panel.id}}
          data-panel-id={{panel.id}}
          {{this.registerWidget}}
        >
          <div class="grid-stack-item-content">
            <div class="custom-dashboard__card-header">
              {{#if @customizing}}
                <span class="custom-dashboard__card-drag-handle">&#x2807;</span>
              {{/if}}
              {{#if (eq this._editingTitlePanelId panel.id)}}
                <input
                  type="text"
                  class="custom-dashboard__card-title-input"
                  value={{this._editingTitleValue}}
                  {{focusInput}}
                  {{on "input" this.onTitleInput}}
                  {{on "keydown" (fn this.onTitleKeydown panel.id)}}
                  {{on "blur" (fn this.saveTitleEdit panel.id)}}
                />
              {{else if @customizing}}
                <span
                  class="custom-dashboard__card-title"
                  role="button"
                  tabindex="0"
                  {{on "click" (fn this.startTitleEdit panel.id panel.title)}}
                  {{on "keydown" (fn this.startTitleEdit panel.id panel.title)}}
                >
                  {{panel.title}}
                  <span class="custom-dashboard__card-title-edit-icon">
                    {{icon "pencil"}}
                  </span>
                </span>
              {{else}}
                <span class="custom-dashboard__card-title">
                  {{panel.title}}
                </span>
              {{/if}}
              {{#if @customizing}}
                <div class="custom-dashboard__card-actions">
                  <button
                    class="custom-dashboard__card-edit btn-flat"
                    type="button"
                    title={{i18n "admin.dashboard_v2.card.edit"}}
                    {{on "click" (fn this.editCard panel)}}
                  >
                    {{icon "pencil"}}
                  </button>
                  <button
                    class="custom-dashboard__card-remove btn-flat"
                    type="button"
                    {{on "click" (fn @onRemovePanel panel.id)}}
                  >
                    {{icon "xmark"}}
                  </button>
                </div>
              {{/if}}
            </div>
            <div class="custom-dashboard__card-content">
              <DashboardCard
                @panel={{panel}}
                @startDate={{@startDate}}
                @endDate={{@endDate}}
              />
            </div>
          </div>
        </div>
      {{/each}}
    </div>
  </template>
}
