# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::ForumAnalyst do
  subject(:forum_analyst) { described_class.new }

  before { enable_current_plugin }

  it "includes the correct tools" do
    expect(forum_analyst.tools).to eq(
      [DiscourseAi::Personas::Tools::DbSchema, DiscourseAi::Personas::Tools::RunDataExplorerQuery],
    )
  end

  it "has a temperature of 0.2" do
    expect(forum_analyst.temperature).to eq(0.2)
  end

  it "includes index-awareness instructions in system prompt" do
    prompt = forum_analyst.system_prompt
    expect(prompt).to include("index")
  end

  it "includes chart type guidance in system prompt" do
    prompt = forum_analyst.system_prompt
    expect(prompt).to include("time series")
    expect(prompt).to include("line")
    expect(prompt).to include("bar")
    expect(prompt).to include("pie")
  end
end
