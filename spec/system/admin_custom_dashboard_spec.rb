# frozen_string_literal: true

describe "Admin Custom Dashboard V2", type: :system do
  fab!(:admin)

  let(:dashboard_page) { PageObjects::Pages::AdminCustomDashboard.new }

  def create_dashboard_with_panels(*panels)
    CustomDashboard.find_or_create_for(admin).tap { |d| d.update!(data: { "panels" => panels }) }
  end

  def default_panel(overrides = {})
    {
      "id" => "test1",
      "type" => "data_explorer",
      "source" => "-20",
      "title" => "Dashboard: Active Users",
      "gridPos" => {
        "x" => 0,
        "y" => 0,
        "w" => 3,
        "h" => 8,
      },
    }.deep_merge(overrides)
  end

  before do
    skip("Requires discourse-data-explorer plugin") unless defined?(DiscourseDataExplorer)
    SiteSetting.data_explorer_enabled = true
    sign_in(admin)
  end

  it "renders the dashboard with the query palette replacing the sidebar" do
    dashboard_page.visit

    expect(dashboard_page).to have_dashboard
    expect(dashboard_page).to have_sidebar_replaced
    expect(dashboard_page).to have_query_palette
  end

  it "restores the admin sidebar when navigating away" do
    dashboard_page.visit
    expect(dashboard_page).to have_dashboard

    dashboard_page.navigate_to_admin

    expect(dashboard_page).to have_admin_sidebar
    expect(dashboard_page).to have_no_dashboard
  end

  context "with query palette" do
    it "displays queries grouped under Dashboard and filters them" do
      dashboard_page.visit

      expect(dashboard_page).to have_palette_group("Dashboard")
      expect(dashboard_page).to have_palette_item("Dashboard: Active Users")
      expect(dashboard_page).to have_palette_item("Dashboard: New Signups")
      expect(dashboard_page).to have_palette_item("Dashboard: New Posts")

      dashboard_page.search_palette("signups")

      expect(dashboard_page).to have_palette_item("Dashboard: New Signups")
      expect(dashboard_page).to have_no_palette_item("Dashboard: Active Users")
      expect(dashboard_page).to have_no_palette_item("Dashboard: New Posts")
    end

    it "collapses and expands palette groups" do
      dashboard_page.visit

      expect(dashboard_page).to have_palette_item("Dashboard: Active Users")

      dashboard_page.toggle_palette_group("Dashboard")
      expect(dashboard_page).to have_no_palette_item("Dashboard: Active Users")

      dashboard_page.toggle_palette_group("Dashboard")
      expect(dashboard_page).to have_palette_item("Dashboard: Active Users")
    end

    it "does not add a card when clicking a palette query" do
      dashboard_page.visit

      dashboard_page.click_palette_item("Dashboard: New Signups")
      expect(dashboard_page).to have_no_card("Dashboard: New Signups")
    end
  end

  context "with grid layout" do
    it "displays grid cells and renders pre-configured cards" do
      create_dashboard_with_panels(
        default_panel,
        default_panel(
          "id" => "test2",
          "source" => "-21",
          "title" => "Dashboard: New Signups",
          "gridPos" => {
            "x" => 3,
            "y" => 0,
            "w" => 3,
            "h" => 8,
          },
        ),
      )

      dashboard_page.visit

      expect(dashboard_page).to have_grid_cells
      expect(dashboard_page).to have_card_count(2)
      expect(dashboard_page).to have_card_at_position("Dashboard: Active Users", 0, 0)
      expect(dashboard_page).to have_card_at_position("Dashboard: New Signups", 3, 0)
    end

    it "repositions a card via drag-and-drop and allows repeated repositioning" do
      create_dashboard_with_panels(default_panel)

      dashboard_page.visit
      expect(dashboard_page).to have_card_at_position("Dashboard: Active Users", 0, 0)

      dashboard_page.drag_card_to_cell("Dashboard: Active Users", 3, 0)
      expect(dashboard_page).to have_card_at_position("Dashboard: Active Users", 3, 0)

      dashboard_page.drag_card_to_cell("Dashboard: Active Users", 0, 0)
      expect(dashboard_page).to have_card_at_position("Dashboard: Active Users", 0, 0)
    end

    it "removes a card when clicking the remove button" do
      create_dashboard_with_panels(
        default_panel,
        default_panel(
          "id" => "test2",
          "source" => "-21",
          "title" => "Dashboard: New Signups",
          "gridPos" => {
            "x" => 3,
            "y" => 0,
            "w" => 3,
            "h" => 8,
          },
        ),
      )

      dashboard_page.visit
      expect(dashboard_page).to have_card_count(2)

      dashboard_page.remove_card("Dashboard: Active Users")

      expect(dashboard_page).to have_no_card("Dashboard: Active Users")
      expect(dashboard_page).to have_card("Dashboard: New Signups")
      expect(dashboard_page).to have_card_count(1)
    end

    it "persists layout changes across page reloads" do
      create_dashboard_with_panels(default_panel)

      dashboard_page.visit
      expect(dashboard_page).to have_card_at_position("Dashboard: Active Users", 0, 0)

      dashboard_page.drag_card_to_cell("Dashboard: Active Users", 3, 0)
      expect(dashboard_page).to have_card_at_position("Dashboard: Active Users", 3, 0)

      dashboard_page.visit
      expect(dashboard_page).to have_card_at_position("Dashboard: Active Users", 3, 0)
    end
  end

  context "with card resizing" do
    it "resizes a card and shows a resize handle" do
      create_dashboard_with_panels(default_panel)

      dashboard_page.visit
      expect(dashboard_page).to have_card_with_size("Dashboard: Active Users", 3, 8)
      expect(dashboard_page).to have_resize_handle("Dashboard: Active Users")

      dashboard_page.resize_card("Dashboard: Active Users", 4, 10)

      expect(dashboard_page).to have_card_with_size("Dashboard: Active Users", 4, 10)
    end

    it "clamps resize to minimum card size of 2x4" do
      create_dashboard_with_panels(default_panel)

      dashboard_page.visit
      expect(dashboard_page).to have_card("Dashboard: Active Users")

      dashboard_page.resize_card("Dashboard: Active Users", 1, 2)

      expect(dashboard_page).to have_card_with_size("Dashboard: Active Users", 2, 4)
    end

    it "prevents resizing into an adjacent card" do
      create_dashboard_with_panels(
        default_panel,
        default_panel(
          "id" => "test2",
          "source" => "-21",
          "title" => "Dashboard: New Signups",
          "gridPos" => {
            "x" => 3,
            "y" => 0,
            "w" => 3,
            "h" => 8,
          },
        ),
      )

      dashboard_page.visit
      expect(dashboard_page).to have_card_count(2)

      dashboard_page.resize_card("Dashboard: Active Users", 5, 8)

      expect(dashboard_page).to have_card_with_size("Dashboard: Active Users", 3, 8)
    end

    it "persists resized card dimensions across page reloads" do
      create_dashboard_with_panels(default_panel)

      dashboard_page.visit
      expect(dashboard_page).to have_card_with_size("Dashboard: Active Users", 3, 8)

      dashboard_page.resize_card("Dashboard: Active Users", 4, 10)
      expect(dashboard_page).to have_card_with_size("Dashboard: Active Users", 4, 10)

      dashboard_page.visit
      expect(dashboard_page).to have_card_with_size("Dashboard: Active Users", 4, 10)
    end
  end

  context "with date range toolbar" do
    it "shows the toolbar with 7d active and allows switching presets" do
      dashboard_page.visit

      expect(dashboard_page).to have_toolbar
      expect(dashboard_page).to have_active_date_preset("7d")

      dashboard_page.click_date_preset("30d")
      expect(dashboard_page).to have_active_date_preset("30d")

      dashboard_page.click_date_preset("14d")
      expect(dashboard_page).to have_active_date_preset("14d")
    end

    it "shows and hides the custom date picker" do
      dashboard_page.visit

      expect(dashboard_page).to have_no_custom_date_picker

      dashboard_page.click_date_preset("Custom")
      expect(dashboard_page).to have_custom_date_picker
      expect(dashboard_page).to have_active_date_preset("Custom")

      dashboard_page.click_date_preset("7d")
      expect(dashboard_page).to have_no_custom_date_picker
      expect(dashboard_page).to have_active_date_preset("7d")
    end
  end
end
