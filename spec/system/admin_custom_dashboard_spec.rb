# frozen_string_literal: true

describe "Admin Custom Dashboard V2", type: :system do
  fab!(:admin)

  let(:dashboard_page) { PageObjects::Pages::AdminCustomDashboard.new }

  before do
    skip("Requires discourse-data-explorer plugin") unless defined?(DiscourseDataExplorer)
    SiteSetting.data_explorer_enabled = true
    sign_in(admin)
  end

  it "renders the custom dashboard with the query palette in the sidebar" do
    dashboard_page.visit

    expect(page).to have_css(".admin-dashboard-v2")
    expect(page).to have_css(".custom-dashboard")
    expect(dashboard_page).to have_query_palette
    expect(page).to have_css(".sidebar-wrapper .dashboard-query-palette")
    expect(page).to have_no_css(".sidebar-container", visible: true)
  end

  it "restores the admin sidebar when navigating away" do
    dashboard_page.visit

    expect(page).to have_css(".custom-dashboard")
    expect(page).to have_no_css(".sidebar-container", visible: true)

    find(".d-breadcrumbs__item a", text: "Admin").click

    expect(page).to have_css(".sidebar-container", visible: true)
    expect(page).to have_no_css(".custom-dashboard")
  end

  context "with query palette" do
    it "displays Data Explorer queries grouped under Dashboard" do
      dashboard_page.visit

      expect(dashboard_page).to have_query_palette
      expect(dashboard_page).to have_palette_group("Dashboard")
      expect(dashboard_page).to have_palette_item("Dashboard: Active Users")
      expect(dashboard_page).to have_palette_item("Dashboard: New Signups")
      expect(dashboard_page).to have_palette_item("Dashboard: New Posts")
    end

    it "filters queries when searching" do
      dashboard_page.visit

      expect(dashboard_page).to have_palette_item("Dashboard: Active Users")
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
    it "displays placeholder grid cells on page load" do
      dashboard_page.visit
      expect(dashboard_page).to have_grid_cells
    end

    it "repositions a card when dragged to a different grid cell" do
      CustomDashboard
        .find_or_create_for(admin)
        .tap do |d|
          d.update!(
            data: {
              "panels" => [
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
                },
              ],
            },
          )
        end

      dashboard_page.visit
      expect(dashboard_page).to have_card("Dashboard: Active Users")
      expect(dashboard_page.card_grid_position("Dashboard: Active Users")).to eq({ x: 0, y: 0 })

      dashboard_page.drag_card_to_cell("Dashboard: Active Users", 3, 0)

      expect(dashboard_page).to have_card_at_position("Dashboard: Active Users", 3, 0)
    end

    it "allows repositioning a card multiple times" do
      CustomDashboard
        .find_or_create_for(admin)
        .tap do |d|
          d.update!(
            data: {
              "panels" => [
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
                },
              ],
            },
          )
        end

      dashboard_page.visit
      expect(dashboard_page).to have_card("Dashboard: Active Users")

      dashboard_page.drag_card_to_cell("Dashboard: Active Users", 3, 0)
      expect(dashboard_page).to have_card_at_position("Dashboard: Active Users", 3, 0)

      dashboard_page.drag_card_to_cell("Dashboard: Active Users", 0, 0)
      expect(dashboard_page).to have_card_at_position("Dashboard: Active Users", 0, 0)
    end
  end

  context "with card resizing" do
    it "resizes a card wider and taller" do
      CustomDashboard
        .find_or_create_for(admin)
        .tap do |d|
          d.update!(
            data: {
              "panels" => [
                {
                  "id" => "resize1",
                  "type" => "data_explorer",
                  "source" => "-20",
                  "title" => "Dashboard: Active Users",
                  "gridPos" => {
                    "x" => 0,
                    "y" => 0,
                    "w" => 3,
                    "h" => 8,
                  },
                },
              ],
            },
          )
        end

      dashboard_page.visit
      expect(dashboard_page).to have_card("Dashboard: Active Users")
      expect(dashboard_page).to have_card_with_size("Dashboard: Active Users", 3, 8)

      dashboard_page.resize_card("Dashboard: Active Users", 4, 10)

      expect(dashboard_page).to have_card_with_size("Dashboard: Active Users", 4, 10)
    end

    it "respects minimum card size" do
      CustomDashboard
        .find_or_create_for(admin)
        .tap do |d|
          d.update!(
            data: {
              "panels" => [
                {
                  "id" => "resize2",
                  "type" => "data_explorer",
                  "source" => "-20",
                  "title" => "Dashboard: Active Users",
                  "gridPos" => {
                    "x" => 0,
                    "y" => 0,
                    "w" => 3,
                    "h" => 8,
                  },
                },
              ],
            },
          )
        end

      dashboard_page.visit
      expect(dashboard_page).to have_card("Dashboard: Active Users")

      dashboard_page.resize_card("Dashboard: Active Users", 1, 2)

      expect(dashboard_page).to have_card_with_size("Dashboard: Active Users", 2, 4)
    end

    it "prevents resizing into another card" do
      CustomDashboard
        .find_or_create_for(admin)
        .tap do |d|
          d.update!(
            data: {
              "panels" => [
                {
                  "id" => "resize3a",
                  "type" => "data_explorer",
                  "source" => "-20",
                  "title" => "Dashboard: Active Users",
                  "gridPos" => {
                    "x" => 0,
                    "y" => 0,
                    "w" => 3,
                    "h" => 8,
                  },
                },
                {
                  "id" => "resize3b",
                  "type" => "data_explorer",
                  "source" => "-21",
                  "title" => "Dashboard: New Signups",
                  "gridPos" => {
                    "x" => 3,
                    "y" => 0,
                    "w" => 3,
                    "h" => 8,
                  },
                },
              ],
            },
          )
        end

      dashboard_page.visit
      expect(dashboard_page).to have_card("Dashboard: Active Users")
      expect(dashboard_page).to have_card("Dashboard: New Signups")

      dashboard_page.resize_card("Dashboard: Active Users", 5, 8)

      expect(dashboard_page).to have_card_with_size("Dashboard: Active Users", 3, 8)
    end
  end

  context "with date range toolbar" do
    it "shows the date range toolbar with 7d selected by default" do
      dashboard_page.visit

      expect(dashboard_page).to have_toolbar
      expect(dashboard_page).to have_active_date_preset("7d")
    end

    it "switches active preset when clicking a different date range" do
      dashboard_page.visit

      dashboard_page.click_date_preset("30d")
      expect(dashboard_page).to have_active_date_preset("30d")

      dashboard_page.click_date_preset("14d")
      expect(dashboard_page).to have_active_date_preset("14d")
    end

    it "shows the custom date picker when Custom is clicked" do
      dashboard_page.visit

      expect(dashboard_page).to have_no_custom_date_picker

      dashboard_page.click_date_preset("Custom")
      expect(dashboard_page).to have_custom_date_picker
      expect(dashboard_page).to have_active_date_preset("Custom")
    end

    it "hides the custom date picker when switching back to a preset" do
      dashboard_page.visit

      dashboard_page.click_date_preset("Custom")
      expect(dashboard_page).to have_custom_date_picker

      dashboard_page.click_date_preset("7d")
      expect(dashboard_page).to have_no_custom_date_picker
      expect(dashboard_page).to have_active_date_preset("7d")
    end
  end
end
