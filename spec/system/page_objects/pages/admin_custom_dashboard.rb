# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminCustomDashboard < PageObjects::Pages::Base
      DASHBOARD_SELECTOR = ".custom-dashboard"
      PALETTE_SELECTOR = ".dashboard-query-palette"
      PALETTE_ITEM_SELECTOR = ".dashboard-query-palette__item"
      PALETTE_GROUP_HEADER_SELECTOR = ".dashboard-query-palette__group-header"
      GRID_SELECTOR = ".custom-dashboard__grid.grid-stack"
      CARD_SELECTOR = ".custom-dashboard__card.grid-stack-item"
      TOOLBAR_SELECTOR = ".custom-dashboard__toolbar"
      CUSTOMIZE_BTN_SELECTOR = ".custom-dashboard__customize-btn"
      DATE_BTN_SELECTOR = ".custom-dashboard__date-btn"

      def visit
        page.visit("/admin/dashboard-v2")
        self
      end

      def has_dashboard?
        has_css?(DASHBOARD_SELECTOR)
      end

      def has_no_dashboard?
        has_no_css?(DASHBOARD_SELECTOR)
      end

      def has_sidebar_replaced?
        has_css?(".sidebar-wrapper #{PALETTE_SELECTOR}") &&
          has_no_css?(".sidebar-container", visible: true)
      end

      def has_admin_sidebar?
        has_css?(".sidebar-container", visible: true)
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

      def has_grid?
        has_css?(GRID_SELECTOR)
      end

      def has_card?(title)
        has_css?(CARD_SELECTOR, text: title)
      end

      def has_no_card?(title)
        has_no_css?(CARD_SELECTOR, text: title)
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

      def has_resize_handle?(title)
        find(CARD_SELECTOR, text: title).has_css?(".ui-resizable-handle", visible: :all)
      end

      def has_grid_cells?(_count = nil)
        has_css?(GRID_SELECTOR)
      end

      def click_customize
        find(CUSTOMIZE_BTN_SELECTOR).click
        self
      end

      def has_customize_button?
        has_css?(CUSTOMIZE_BTN_SELECTOR)
      end

      def has_customizing_active?
        has_css?("#{CUSTOMIZE_BTN_SELECTOR}.btn-primary")
      end

      def has_no_customizing_active?
        has_no_css?("#{CUSTOMIZE_BTN_SELECTOR}.btn-primary")
      end

      def has_drag_handle?(title)
        find(CARD_SELECTOR, text: title).has_css?(".custom-dashboard__card-drag-handle")
      end

      def has_no_drag_handle?(title)
        find(CARD_SELECTOR, text: title).has_no_css?(".custom-dashboard__card-drag-handle")
      end

      def has_remove_button?(title)
        find(CARD_SELECTOR, text: title).has_css?(".custom-dashboard__card-remove")
      end

      def has_no_remove_button?(title)
        find(CARD_SELECTOR, text: title).has_no_css?(".custom-dashboard__card-remove")
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

      def navigate_to_admin
        find(".d-breadcrumbs__item a", text: "Admin").click
        self
      end

      def drag_card_to_cell(panel_title, col, row)
        card = find(CARD_SELECTOR, text: panel_title)
        panel_id = card["data-panel-id"]

        page.execute_script(<<~JS, panel_id, col, row)
          const panelId = arguments[0];
          const targetCol = arguments[1];
          const targetRow = arguments[2];
          const gridEl = document.querySelector('.grid-stack');
          const grid = gridEl.gridstack;
          const card = document.querySelector(`.grid-stack-item[data-panel-id="${panelId}"]`);

          if (grid && card) {
            grid.update(card, { x: targetCol, y: targetRow });
          }
        JS
        self
      end

      def has_card_at_position?(panel_title, col, row)
        has_css?("#{CARD_SELECTOR}[gs-x='#{col}'][gs-y='#{row}']", text: panel_title)
      end

      def has_card_with_chart?(panel_title)
        find(CARD_SELECTOR, text: panel_title).has_css?(".custom-dashboard__card-chart canvas")
      end

      def has_card_with_table?(panel_title)
        find(CARD_SELECTOR, text: panel_title).has_css?(".custom-dashboard__card-table")
      end

      def has_card_with_no_chart?(panel_title)
        find(CARD_SELECTOR, text: panel_title).has_no_css?(".custom-dashboard__card-chart canvas")
      end

      def has_card_with_size?(panel_title, w, h)
        has_css?("#{CARD_SELECTOR}[gs-w='#{w}'][gs-h='#{h}']", text: panel_title)
      end

      def has_no_card_with_size?(panel_title, w, h)
        has_no_css?("#{CARD_SELECTOR}[gs-w='#{w}'][gs-h='#{h}']", text: panel_title)
      end

      def wait_for_save
        # The dashboard debounces saves by 1 second; wait for it to fire + network round-trip
        sleep 2
      end

      def resize_card(panel_title, new_w, new_h)
        card = find(CARD_SELECTOR, text: panel_title)
        panel_id = card["data-panel-id"]

        page.execute_script(<<~JS, panel_id, new_w, new_h)
          const panelId = arguments[0];
          const targetW = arguments[1];
          const targetH = arguments[2];
          const gridEl = document.querySelector('.grid-stack');
          const grid = gridEl.gridstack;
          const card = document.querySelector(`.grid-stack-item[data-panel-id="${panelId}"]`);

          if (grid && card) {
            grid.update(card, { w: targetW, h: targetH });
          }
        JS
        self
      end
    end
  end
end
