# frozen_string_literal: true

describe "Admin Dashboard AI Sidebar", type: :system do
  fab!(:admin)

  let(:dashboard_page) { PageObjects::Pages::AdminCustomDashboard.new }
  let(:sidebar_page) { PageObjects::Pages::AdminDashboardAiSidebar.new }

  before do
    skip("Requires discourse-data-explorer plugin") unless defined?(DiscourseDataExplorer)
    SiteSetting.data_explorer_enabled = true
    sign_in(admin)
  end

  context "when discourse-ai is not available" do
    it "does not render the AI sidebar" do
      dashboard_page.visit

      expect(dashboard_page).to have_dashboard
      expect(sidebar_page).to have_no_sidebar
    end
  end

  context "when discourse-ai is available" do
    before do
      skip("Requires discourse-ai plugin") unless defined?(DiscourseAi)
      SiteSetting.discourse_ai_enabled = true
      SiteSetting.ai_bot_enabled = true
    end

    it "renders the AI sidebar" do
      dashboard_page.visit

      expect(dashboard_page).to have_dashboard
      expect(sidebar_page).to have_sidebar
    end

    it "shows unavailable state when no Dashboard Designer persona exists" do
      dashboard_page.visit

      expect(sidebar_page).to have_sidebar
      expect(sidebar_page).to have_unavailable_state
    end
  end
end
