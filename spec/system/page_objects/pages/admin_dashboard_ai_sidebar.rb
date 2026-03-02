# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminDashboardAiSidebar < PageObjects::Pages::Base
      SIDEBAR_SELECTOR = ".dashboard-ai-sidebar"
      MESSAGE_SELECTOR = ".dashboard-ai-sidebar__message"
      USER_MESSAGE_SELECTOR = ".dashboard-ai-sidebar__message--user"
      BOT_MESSAGE_SELECTOR = ".dashboard-ai-sidebar__message--bot"
      INPUT_SELECTOR = ".dashboard-ai-sidebar__textarea"
      SEND_BTN_SELECTOR = ".dashboard-ai-sidebar__send-btn"
      CHART_PREVIEW_SELECTOR = ".dashboard-chart-preview"
      ADD_BTN_SELECTOR = ".dashboard-chart-preview__add-btn"
      LOADING_SELECTOR = ".dashboard-ai-sidebar__thinking"
      EMPTY_SELECTOR = ".dashboard-ai-sidebar__empty"
      UNAVAILABLE_SELECTOR = ".dashboard-ai-sidebar__unavailable"

      def has_sidebar?
        has_css?(SIDEBAR_SELECTOR)
      end

      def has_no_sidebar?
        has_no_css?(SIDEBAR_SELECTOR)
      end

      def send_message(text)
        find(INPUT_SELECTOR).fill_in(with: text)
        find(SEND_BTN_SELECTOR).click
        self
      end

      def has_message?(text)
        has_css?(MESSAGE_SELECTOR, text: text)
      end

      def has_no_message?(text)
        has_no_css?(MESSAGE_SELECTOR, text: text)
      end

      def has_user_message?
        has_css?(USER_MESSAGE_SELECTOR)
      end

      def has_bot_message?
        has_css?(BOT_MESSAGE_SELECTOR)
      end

      def has_chart_preview?
        has_css?(CHART_PREVIEW_SELECTOR)
      end

      def has_no_chart_preview?
        has_no_css?(CHART_PREVIEW_SELECTOR)
      end

      def click_add_to_dashboard
        find(ADD_BTN_SELECTOR).click
        self
      end

      def has_loading_indicator?
        has_css?(LOADING_SELECTOR)
      end

      def has_no_loading_indicator?
        has_no_css?(LOADING_SELECTOR)
      end

      def has_empty_state?
        has_css?(EMPTY_SELECTOR)
      end

      def has_unavailable_state?
        has_css?(UNAVAILABLE_SELECTOR)
      end

      def has_input_disabled?
        find(INPUT_SELECTOR).disabled?
      end
    end
  end
end
