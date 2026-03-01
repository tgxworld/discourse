# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminCustomDashboard < PageObjects::Pages::Base
      PALETTE_SELECTOR = ".dashboard-query-palette"
      PALETTE_ITEM_SELECTOR = ".dashboard-query-palette__item"
      PALETTE_GROUP_HEADER_SELECTOR = ".dashboard-query-palette__group-header"
      GRID_CELL_SELECTOR = ".custom-dashboard__grid-cell"
      CARD_SELECTOR = ".custom-dashboard__card"
      HIGHLIGHTED_CELL_SELECTOR = ".custom-dashboard__grid-cell--highlight"
      TOOLBAR_SELECTOR = ".custom-dashboard__toolbar"
      DATE_BTN_SELECTOR = ".custom-dashboard__date-btn"

      def visit
        page.visit("/admin/dashboard-v2")
        self
      end

      def has_query_palette?
        has_css?(PALETTE_SELECTOR)
      end

      def has_no_query_palette?
        has_no_css?(PALETTE_SELECTOR)
      end

      def has_palette_item?(text)
        has_css?(PALETTE_ITEM_SELECTOR, text: text)
      end

      def has_no_palette_item?(text)
        has_no_css?(PALETTE_ITEM_SELECTOR, text: text)
      end

      def has_palette_group?(text)
        has_css?(PALETTE_GROUP_HEADER_SELECTOR, text: text)
      end

      def has_grid_cells?(count = nil)
        if count
          has_css?(GRID_CELL_SELECTOR, count: count)
        else
          has_css?(GRID_CELL_SELECTOR)
        end
      end

      def has_no_grid_cells?
        has_no_css?(GRID_CELL_SELECTOR)
      end

      def has_card?(title)
        has_css?(CARD_SELECTOR, text: title)
      end

      def has_no_card?(title)
        has_no_css?(CARD_SELECTOR, text: title)
      end

      def has_highlighted_cell?
        has_css?(HIGHLIGHTED_CELL_SELECTOR)
      end

      def has_no_highlighted_cell?
        has_no_css?(HIGHLIGHTED_CELL_SELECTOR)
      end

      def has_card_count?(count)
        has_css?(CARD_SELECTOR, count: count)
      end

      def has_toolbar?
        has_css?(TOOLBAR_SELECTOR)
      end

      def has_active_date_preset?(label)
        has_css?("#{DATE_BTN_SELECTOR}.btn-primary", text: label)
      end

      def has_custom_date_picker?
        has_css?(".custom-dashboard__date-picker-panel")
      end

      def has_no_custom_date_picker?
        has_no_css?(".custom-dashboard__date-picker-panel")
      end

      def click_date_preset(label)
        find(DATE_BTN_SELECTOR, text: label).click
        self
      end

      def search_palette(query)
        find(".dashboard-query-palette__search").fill_in(with: query)
        self
      end

      def click_palette_item(text)
        find("#{PALETTE_ITEM_SELECTOR} .dashboard-query-palette__item-name", text: text).click
        self
      end

      def toggle_palette_group(text)
        find(PALETTE_GROUP_HEADER_SELECTOR, text: text).click
        self
      end

      def remove_card(title)
        find(CARD_SELECTOR, text: title).find(".custom-dashboard__card-remove").click
        self
      end

      def drag_card_to_cell(panel_title, col, row)
        card = find(CARD_SELECTOR, text: panel_title)
        panel_id = card["data-panel-id"]
        target_selector = "#{GRID_CELL_SELECTOR}[data-col='#{col}'][data-row='#{row}']"

        page.execute_script(<<~JS, panel_id, target_selector)
          const panelId = arguments[0];
          const targetSelector = arguments[1];
          const card = document.querySelector(`.custom-dashboard__card[data-panel-id="${panelId}"]`);
          const handle = card.querySelector('.custom-dashboard__card-drag-handle');
          const target = document.querySelector(targetSelector);
          const grid = document.querySelector('.custom-dashboard__grid');

          function createDragEvent(type, element, dataTransfer) {
            const rect = element.getBoundingClientRect();
            return new DragEvent(type, {
              bubbles: true,
              cancelable: true,
              clientX: rect.left + rect.width / 2,
              clientY: rect.top + rect.height / 2,
              dataTransfer: dataTransfer,
            });
          }

          const dt = new DataTransfer();
          dt.setData('panel-id', panelId);

          handle.dispatchEvent(createDragEvent('dragstart', handle, dt));
          grid.dispatchEvent(createDragEvent('dragenter', grid, dt));

          target.dispatchEvent(createDragEvent('dragover', target, dt));
          target.dispatchEvent(createDragEvent('drop', target, dt));
          grid.dispatchEvent(createDragEvent('dragleave', grid, dt));
          handle.dispatchEvent(createDragEvent('dragend', handle, dt));
        JS
        self
      end

      def card_grid_position(panel_title)
        card = find(CARD_SELECTOR, text: panel_title)
        style = card[:style]
        col_match = style.match(/grid-column:\s*(\d+)/)
        row_match = style.match(/grid-row:\s*(\d+)/)
        return nil unless col_match && row_match
        { x: col_match[1].to_i - 1, y: row_match[1].to_i - 1 }
      end

      def has_card_at_position?(panel_title, col, row)
        css_col = col + 1
        css_row = row + 1
        has_css?(
          "#{CARD_SELECTOR}[style*='grid-column: #{css_col}'][style*='grid-row: #{css_row}']",
          text: panel_title,
        )
      end

      def has_card_with_size?(panel_title, w, h)
        has_css?("#{CARD_SELECTOR}[style*='span #{w}'][style*='span #{h}']", text: panel_title)
      end

      def resize_card(panel_title, new_w, new_h)
        card = find(CARD_SELECTOR, text: panel_title)
        panel_id = card["data-panel-id"]

        page.execute_script(<<~JS, panel_id, new_w, new_h)
          const panelId = arguments[0];
          const targetW = arguments[1];
          const targetH = arguments[2];
          const card = document.querySelector(`.custom-dashboard__card[data-panel-id="${panelId}"]`);
          const handle = card.querySelector('.custom-dashboard__card-resize-handle');
          const grid = document.querySelector('.custom-dashboard__grid');

          const gridRect = grid.getBoundingClientRect();
          const gridStyle = window.getComputedStyle(grid);
          const gap = parseFloat(gridStyle.gap) || 12;
          const padding = parseFloat(gridStyle.paddingLeft) || 16;
          const totalGaps = gap * 5;
          const usableWidth = gridRect.width - padding * 2 - totalGaps;
          const cellW = usableWidth / 6;
          const cellH = 40;

          const style = card.getAttribute('style');
          const spanWMatch = style.match(/grid-column:[^;]*span\\s+(\\d+)/);
          const spanHMatch = style.match(/grid-row:[^;]*span\\s+(\\d+)/);
          const currentW = spanWMatch ? parseInt(spanWMatch[1]) : 3;
          const currentH = spanHMatch ? parseInt(spanHMatch[1]) : 8;

          const deltaW = targetW - currentW;
          const deltaH = targetH - currentH;
          const pixelDX = deltaW * (cellW + gap);
          const pixelDY = deltaH * (cellH + gap);

          const handleRect = handle.getBoundingClientRect();
          const startX = handleRect.left + handleRect.width / 2;
          const startY = handleRect.top + handleRect.height / 2;

          handle.dispatchEvent(new PointerEvent('pointerdown', {
            bubbles: true, cancelable: true, clientX: startX, clientY: startY
          }));

          window.dispatchEvent(new PointerEvent('pointermove', {
            bubbles: true, cancelable: true, clientX: startX + pixelDX, clientY: startY + pixelDY
          }));

          window.dispatchEvent(new PointerEvent('pointerup', {
            bubbles: true, cancelable: true, clientX: startX + pixelDX, clientY: startY + pixelDY
          }));
        JS
        self
      end
    end
  end
end
