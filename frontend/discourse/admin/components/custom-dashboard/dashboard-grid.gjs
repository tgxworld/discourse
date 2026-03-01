import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import icon from "discourse/helpers/d-icon";
import { bind } from "discourse/lib/decorators";
import DashboardCard from "./dashboard-card";

const GRID_COLS = 6;
const ROW_HEIGHT = 40;
const GAP = 12;
const PADDING = 16;
const DEFAULT_CARD_W = 3;
const DEFAULT_CARD_H = 8;
const MIN_CARD_W = 2;
const MIN_CARD_H = 4;
const HIGHLIGHT_CLASS = "custom-dashboard__grid-cell--highlight";
const OVERLAP_CLASS = "custom-dashboard__grid-cell--overlap";

export default class DashboardGrid extends Component {
  resizeHandle = modifier((element, [panelId]) => {
    const handler = (event) => this.handleResizeStart(panelId, event);
    element.addEventListener("pointerdown", handler);
    return () => element.removeEventListener("pointerdown", handler);
  });

  measureGrid = modifier((element) => {
    const computeRows = () => {
      const height = element.clientHeight;
      const usable = height - PADDING * 2;
      this._minRows = Math.ceil((usable + GAP) / (ROW_HEIGHT + GAP));
    };
    computeRows();
    const observer = new ResizeObserver(computeRows);
    observer.observe(element);
    return () => observer.disconnect();
  });
  @tracked _minRows = DEFAULT_CARD_H * 4;

  _highlightCol = -1;
  _highlightRow = -1;
  _highlightW = -1;
  _highlightH = -1;
  _gridElement = null;
  _draggingPanelId = null;

  _resizingPanelId = null;
  _resizeStartX = 0;
  _resizeStartY = 0;
  _resizeOrigW = 0;
  _resizeOrigH = 0;
  _resizeCardX = 0;
  _resizeCardY = 0;
  _cellPixelW = 0;
  _cellPixelH = 0;

  get gridRows() {
    let maxRow = 0;
    for (const panel of this.args.panels || []) {
      const bottom = panel.gridPos.y + panel.gridPos.h;
      if (bottom > maxRow) {
        maxRow = bottom;
      }
    }
    return Math.max(maxRow + DEFAULT_CARD_H, this._minRows);
  }

  get cells() {
    const totalRows = this.gridRows;
    const result = [];
    for (let row = 0; row < totalRows; row++) {
      for (let col = 0; col < GRID_COLS; col++) {
        result.push({
          col,
          row,
          style: htmlSafe(
            `grid-column: ${col + 1} / span 1; grid-row: ${row + 1} / span 1;`
          ),
          occupied: this.#isCellOccupied(col, row),
        });
      }
    }
    return result;
  }

  #isCellOccupied(col, row) {
    return this.args.panels?.some((panel) => {
      const { x, y, w, h } = panel.gridPos;
      return col >= x && col < x + w && row >= y && row < y + h;
    });
  }

  #wouldOverlap(
    col,
    row,
    excludePanelId = null,
    cardW = DEFAULT_CARD_W,
    cardH = DEFAULT_CARD_H
  ) {
    const endCol = col + cardW;
    const endRow = row + cardH;
    if (endCol > GRID_COLS) {
      return true;
    }
    return this.args.panels?.some((panel) => {
      if (excludePanelId && panel.id === excludePanelId) {
        return false;
      }
      const { x, y, w, h } = panel.gridPos;
      return col < x + w && endCol > x && row < y + h && endRow > y;
    });
  }

  #highlightCells(
    gridEl,
    col,
    row,
    cardW = DEFAULT_CARD_W,
    cardH = DEFAULT_CARD_H,
    overlap = false
  ) {
    if (
      col === this._highlightCol &&
      row === this._highlightRow &&
      cardW === this._highlightW &&
      cardH === this._highlightH
    ) {
      return;
    }
    this.#clearHighlight(gridEl);
    this._highlightCol = col;
    this._highlightRow = row;
    this._highlightW = cardW;
    this._highlightH = cardH;

    const cls = overlap ? OVERLAP_CLASS : HIGHLIGHT_CLASS;
    const endCol = col + cardW;
    const endRow = row + cardH;
    for (let r = row; r < endRow; r++) {
      for (let c = col; c < endCol; c++) {
        const cell = gridEl.querySelector(
          `.custom-dashboard__grid-cell[data-col="${c}"][data-row="${r}"]`
        );
        if (cell) {
          cell.classList.add(cls);
        }
      }
    }
  }

  #clearHighlight(gridEl) {
    if (this._highlightCol === -1) {
      return;
    }
    gridEl
      .querySelectorAll(`.${HIGHLIGHT_CLASS}, .${OVERLAP_CLASS}`)
      .forEach((el) => {
        el.classList.remove(HIGHLIGHT_CLASS);
        el.classList.remove(OVERLAP_CLASS);
      });
    this._highlightCol = -1;
    this._highlightRow = -1;
    this._highlightW = -1;
    this._highlightH = -1;
  }

  #computeCellDimensions(gridEl) {
    const rect = gridEl.getBoundingClientRect();
    const totalGaps = GAP * (GRID_COLS - 1);
    const usableWidth = rect.width - PADDING * 2 - totalGaps;
    this._cellPixelW = usableWidth / GRID_COLS;
    this._cellPixelH = ROW_HEIGHT;
  }

  gridStyle(panel) {
    const { x, y, w, h } = panel.gridPos;
    return htmlSafe(
      `grid-column: ${x + 1} / span ${w}; grid-row: ${y + 1} / span ${h};`
    );
  }

  @action
  handleGridDragEnter(event) {
    event.preventDefault();
    this._gridElement = event.currentTarget;
    event.currentTarget.classList.add("is-receiving-drag");
  }

  @action
  handleGridDragLeave(event) {
    if (!event.currentTarget.contains(event.relatedTarget)) {
      this.#clearHighlight(event.currentTarget);
      event.currentTarget.classList.remove("is-receiving-drag");
      this._gridElement = null;
    }
  }

  @action
  handleGridDrop() {
    this.#resetDragState();
  }

  @action
  handleDragOver(event) {
    const cell = event.currentTarget;
    const col = parseInt(cell.dataset.col, 10);
    const row = parseInt(cell.dataset.row, 10);

    const draggingPanel = this._draggingPanelId
      ? this.args.panels?.find((p) => p.id === this._draggingPanelId)
      : null;
    const cardW = draggingPanel ? draggingPanel.gridPos.w : DEFAULT_CARD_W;
    const cardH = draggingPanel ? draggingPanel.gridPos.h : DEFAULT_CARD_H;

    const overlap = this.#wouldOverlap(
      col,
      row,
      this._draggingPanelId,
      cardW,
      cardH
    );
    if (!overlap) {
      event.preventDefault();
      event.dataTransfer.dropEffect = this._draggingPanelId ? "move" : "copy";
    }
    if (this._gridElement) {
      this.#highlightCells(this._gridElement, col, row, cardW, cardH, overlap);
    }
  }

  @action
  handleDragLeave() {
    // Highlight is managed at the grid level via #highlightCells/#clearHighlight
  }

  @action
  handleCardDragStart(panelId, event) {
    if (this._resizingPanelId) {
      event.preventDefault();
      return;
    }
    this._draggingPanelId = panelId;
    event.dataTransfer.setData("panel-id", panelId);
    event.dataTransfer.effectAllowed = "move";
    const card = event.target.closest(".custom-dashboard__card");
    if (card) {
      card.classList.add("custom-dashboard__card--dragging");
    }
  }

  @action
  handleCardDragEnd(event) {
    const card = event.target.closest(".custom-dashboard__card");
    if (card) {
      card.classList.remove("custom-dashboard__card--dragging");
    }
    this.#resetDragState();
  }

  #resetDragState() {
    this._draggingPanelId = null;
    if (this._gridElement) {
      this.#clearHighlight(this._gridElement);
      this._gridElement.classList.remove("is-receiving-drag");
      this._gridElement = null;
    }
  }

  @action
  handleDrop(event) {
    event.preventDefault();
    event.stopPropagation();
    this.#resetDragState();

    const cell = event.currentTarget;
    const col = parseInt(cell.dataset.col, 10);
    const row = parseInt(cell.dataset.row, 10);

    const panelId = event.dataTransfer.getData("panel-id");
    if (panelId) {
      const panel = this.args.panels?.find((p) => p.id === panelId);
      if (!panel) {
        return;
      }
      const { w, h } = panel.gridPos;
      if (this.#wouldOverlap(col, row, panelId, w, h)) {
        return;
      }
      const updatedPanels = this.args.panels.map((p) => {
        if (p.id === panelId) {
          return { ...p, gridPos: { ...p.gridPos, x: col, y: row } };
        }
        return p;
      });
      this.args.onUpdateLayout(updatedPanels);
      return;
    }

    if (this.#wouldOverlap(col, row)) {
      return;
    }

    const queryId = event.dataTransfer.getData("query-id");
    const queryName = event.dataTransfer.getData("query-name");

    if (!queryId) {
      return;
    }

    const gridPos = { x: col, y: row, w: DEFAULT_CARD_W, h: DEFAULT_CARD_H };

    this.args.onAddPanel("data_explorer", queryId, queryName, gridPos);
  }

  @action
  handleResizeStart(panelId, event) {
    event.preventDefault();
    event.stopPropagation();

    const panel = this.args.panels?.find((p) => p.id === panelId);
    if (!panel) {
      return;
    }

    this._resizingPanelId = panelId;
    this._resizeStartX = event.clientX;
    this._resizeStartY = event.clientY;
    this._resizeOrigW = panel.gridPos.w;
    this._resizeOrigH = panel.gridPos.h;
    this._resizeCardX = panel.gridPos.x;
    this._resizeCardY = panel.gridPos.y;

    const gridEl = event.target.closest(".custom-dashboard__grid");
    this._gridElement = gridEl;
    this.#computeCellDimensions(gridEl);

    const card = event.target.closest(".custom-dashboard__card");
    if (card) {
      card.classList.add("custom-dashboard__card--resizing");
    }
    gridEl.classList.add("is-receiving-drag");
    document.body.classList.add("is-resizing-dashboard-card");

    this.#highlightCells(
      gridEl,
      this._resizeCardX,
      this._resizeCardY,
      this._resizeOrigW,
      this._resizeOrigH,
      false
    );

    window.addEventListener("pointermove", this._handleResizeMove);
    window.addEventListener("pointerup", this._handleResizeEnd);
  }

  @bind
  _handleResizeMove(event) {
    const deltaX = event.clientX - this._resizeStartX;
    const deltaY = event.clientY - this._resizeStartY;

    const colDelta = Math.round(deltaX / (this._cellPixelW + GAP));
    const rowDelta = Math.round(deltaY / (this._cellPixelH + GAP));

    let newW = Math.max(MIN_CARD_W, this._resizeOrigW + colDelta);
    let newH = Math.max(MIN_CARD_H, this._resizeOrigH + rowDelta);

    newW = Math.min(newW, GRID_COLS - this._resizeCardX);

    const overlap = this.#wouldOverlap(
      this._resizeCardX,
      this._resizeCardY,
      this._resizingPanelId,
      newW,
      newH
    );

    if (this._gridElement) {
      this.#highlightCells(
        this._gridElement,
        this._resizeCardX,
        this._resizeCardY,
        newW,
        newH,
        overlap
      );
    }
  }

  @bind
  _handleResizeEnd(event) {
    const deltaX = event.clientX - this._resizeStartX;
    const deltaY = event.clientY - this._resizeStartY;

    const colDelta = Math.round(deltaX / (this._cellPixelW + GAP));
    const rowDelta = Math.round(deltaY / (this._cellPixelH + GAP));

    let newW = Math.max(MIN_CARD_W, this._resizeOrigW + colDelta);
    let newH = Math.max(MIN_CARD_H, this._resizeOrigH + rowDelta);

    newW = Math.min(newW, GRID_COLS - this._resizeCardX);

    const overlap = this.#wouldOverlap(
      this._resizeCardX,
      this._resizeCardY,
      this._resizingPanelId,
      newW,
      newH
    );

    if (!overlap) {
      const updatedPanels = this.args.panels.map((p) => {
        if (p.id === this._resizingPanelId) {
          return {
            ...p,
            gridPos: { ...p.gridPos, w: newW, h: newH },
          };
        }
        return p;
      });
      this.args.onUpdateLayout(updatedPanels);
    }

    this.#resetResizeState();
  }

  #resetResizeState() {
    const card = this._gridElement?.querySelector(
      `.custom-dashboard__card[data-panel-id="${this._resizingPanelId}"]`
    );
    if (card) {
      card.classList.remove("custom-dashboard__card--resizing");
    }

    if (this._gridElement) {
      this.#clearHighlight(this._gridElement);
      this._gridElement.classList.remove("is-receiving-drag");
    }

    document.body.classList.remove("is-resizing-dashboard-card");

    window.removeEventListener("pointermove", this._handleResizeMove);
    window.removeEventListener("pointerup", this._handleResizeEnd);

    this._resizingPanelId = null;
    this._gridElement = null;
  }

  <template>
    <div
      class="custom-dashboard__grid"
      {{this.measureGrid}}
      {{on "dragenter" this.handleGridDragEnter}}
      {{on "dragleave" this.handleGridDragLeave}}
      {{on "drop" this.handleGridDrop}}
    >
      {{#each this.cells as |cell|}}
        <div
          class="custom-dashboard__grid-cell"
          style={{cell.style}}
          data-col={{cell.col}}
          data-row={{cell.row}}
          data-occupied={{cell.occupied}}
          {{on "dragover" this.handleDragOver}}
          {{on "dragleave" this.handleDragLeave}}
          {{on "drop" this.handleDrop}}
        ></div>
      {{/each}}

      <div class="custom-dashboard__cards">
        {{#each @panels as |panel|}}
          <div
            class="custom-dashboard__card"
            style={{this.gridStyle panel}}
            data-panel-id={{panel.id}}
          >
            <div class="custom-dashboard__card-header">
              <span
                class="custom-dashboard__card-drag-handle"
                draggable="true"
                {{on "dragstart" (fn this.handleCardDragStart panel.id)}}
                {{on "dragend" this.handleCardDragEnd}}
              >&#x2807;</span>
              <span class="custom-dashboard__card-title">{{panel.title}}</span>
              <button
                class="custom-dashboard__card-remove btn-flat"
                type="button"
                {{on "click" (fn @onRemovePanel panel.id)}}
              >
                {{icon "xmark"}}
              </button>
            </div>
            <div class="custom-dashboard__card-content">
              <DashboardCard
                @panel={{panel}}
                @startDate={{@startDate}}
                @endDate={{@endDate}}
              />
            </div>
            <div
              class="custom-dashboard__card-resize-handle"
              {{this.resizeHandle panel.id}}
            >
              {{icon "angles-right"}}
            </div>
          </div>
        {{/each}}
      </div>
    </div>
  </template>
}
