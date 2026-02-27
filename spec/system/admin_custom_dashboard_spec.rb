# frozen_string_literal: true

describe "Admin Custom Dashboard V2", type: :system do
  fab!(:admin)

  before { sign_in(admin) }

  it "loads the custom dashboard page" do
    visit("/admin/dashboard-v2")

    expect(page).to have_css(".admin-dashboard-v2")
    expect(page).to have_css(".custom-dashboard")
  end
end
