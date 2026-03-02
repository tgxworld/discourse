# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::DashboardDesigner do
  subject(:dashboard_designer) { described_class.new }

  before { enable_current_plugin }

  it "includes the correct tools" do
    expect(dashboard_designer.tools).to eq(
      [
        DiscourseAi::Personas::Tools::DbSchema,
        DiscourseAi::Personas::Tools::RunDataExplorerQuery,
        DiscourseAi::Personas::Tools::AddCardToDashboard,
      ],
    )
  end

  it "has a temperature of 0.2" do
    expect(dashboard_designer.temperature).to eq(0.2)
  end

  it "includes index-awareness instructions in system prompt" do
    prompt = dashboard_designer.system_prompt
    expect(prompt).to include("index")
  end

  it "includes chart type guidance in system prompt" do
    prompt = dashboard_designer.system_prompt
    expect(prompt).to include("time series")
    expect(prompt).to include("line")
    expect(prompt).to include("bar")
    expect(prompt).to include("pie")
  end
end
