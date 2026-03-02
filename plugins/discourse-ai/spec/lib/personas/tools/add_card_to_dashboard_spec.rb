# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::AddCardToDashboard do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  let(:progress_blk) { Proc.new {} }

  fab!(:user)
  let(:context) { DiscourseAi::Personas::BotContext.new(user: user) }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  def invoke_tool(params = {})
    tool = described_class.new(params, bot_user: bot_user, llm: llm, context: context)
    tool.invoke(&progress_blk)
  end

  describe "#invoke" do
    let(:sql) { "SELECT id, username FROM users LIMIT 10" }
    let(:title) { "Active Users" }
    let(:chart_type) { "bar" }

    it "creates a Data Explorer query with Dashboard prefix" do
      result = invoke_tool(sql: sql, title: title, chart_type: chart_type)

      query = DiscourseDataExplorer::Query.last
      expect(query.name).to eq("Dashboard: Active Users")
      expect(query.sql).to eq(sql)
      expect(query.user_id).to eq(user.id)
    end

    it "creates a dashboard for the user if one does not exist" do
      expect { invoke_tool(sql: sql, title: title, chart_type: chart_type) }.to change {
        CustomDashboard.where(user: user).count
      }.from(0).to(1)
    end

    it "appends a panel with correct chartType to the dashboard" do
      result = invoke_tool(sql: sql, title: title, chart_type: chart_type)

      dashboard = CustomDashboard.find_by(user: user)
      panels = dashboard.data["panels"]
      expect(panels.length).to eq(1)

      panel = panels.first
      expect(panel["chartType"]).to eq("bar")
      expect(panel["queryId"]).to eq(DiscourseDataExplorer::Query.last.id)
    end

    it "places the first panel at grid position 0,0" do
      invoke_tool(sql: sql, title: title, chart_type: chart_type)

      dashboard = CustomDashboard.find_by(user: user)
      panel = dashboard.data["panels"].first
      expect(panel["gridPos"]["x"]).to eq(0)
      expect(panel["gridPos"]["y"]).to eq(0)
    end

    it "computes the next available grid position when panels already exist" do
      dashboard = CustomDashboard.find_or_create_for(user)
      dashboard.update!(
        data: {
          "panels" => [
            {
              "id" => "panel-1",
              "chartType" => "line",
              "queryId" => 1,
              "gridPos" => {
                "x" => 0,
                "y" => 0,
                "w" => 6,
                "h" => 4,
              },
            },
          ],
        },
      )

      invoke_tool(sql: sql, title: title, chart_type: chart_type)

      dashboard.reload
      panels = dashboard.data["panels"]
      expect(panels.length).to eq(2)

      new_panel = panels.last
      grid_pos = new_panel["gridPos"]
      expect(grid_pos["x"]).to be >= 0
      expect(grid_pos["y"]).to be >= 0
      expect(grid_pos).not_to eq({ "x" => 0, "y" => 0, "w" => 6, "h" => 4 })
    end

    it "assigns a unique panel ID" do
      invoke_tool(sql: sql, title: title, chart_type: chart_type)
      invoke_tool(sql: "SELECT 1", title: "Second Card", chart_type: "line")

      dashboard = CustomDashboard.find_by(user: user)
      panels = dashboard.data["panels"]
      ids = panels.map { |p| p["id"] }
      expect(ids.uniq.length).to eq(2)
    end

    it "supports all valid chart types" do
      %w[line bar pie area table].each do |type|
        result = invoke_tool(sql: sql, title: "#{type} chart", chart_type: type)
        expect(result[:status]).not_to eq("error")
      end

      dashboard = CustomDashboard.find_by(user: user)
      chart_types = dashboard.data["panels"].map { |p| p["chartType"] }
      expect(chart_types).to contain_exactly("line", "bar", "pie", "area", "table")
    end

    it "stores optional param_definitions on the panel" do
      param_defs = "start_date:date end_date:date"
      invoke_tool(
        sql: "SELECT * FROM users WHERE created_at > :start_date AND created_at < :end_date",
        title: title,
        chart_type: chart_type,
        param_definitions: param_defs,
      )

      dashboard = CustomDashboard.find_by(user: user)
      panel = dashboard.data["panels"].first
      expect(panel["paramDefinitions"]).to eq(param_defs)
    end

    it "increments the dashboard version on save" do
      dashboard = CustomDashboard.find_or_create_for(user)
      initial_version = dashboard.version

      invoke_tool(sql: sql, title: title, chart_type: chart_type)

      dashboard.reload
      expect(dashboard.version).to eq(initial_version + 1)
    end

    it "retries on version conflict" do
      dashboard = CustomDashboard.find_or_create_for(user)

      call_count = 0
      original_method = CustomDashboard.method(:find_or_create_for)

      allow(CustomDashboard).to receive(:find_or_create_for).and_wrap_original do |m, *args|
        result = m.call(*args)
        if call_count == 0
          call_count += 1
          CustomDashboard.where(id: result.id).update_all(version: result.version + 1)
        end
        result
      end

      result = invoke_tool(sql: sql, title: title, chart_type: chart_type)

      dashboard.reload
      expect(dashboard.data["panels"].length).to eq(1)
    end

    it "returns success status with query and panel info" do
      result = invoke_tool(sql: sql, title: title, chart_type: chart_type)

      expect(result[:status]).to eq("success")
      expect(result[:query_id]).to be_present
      expect(result[:panel_id]).to be_present
      expect(result[:title]).to eq("Dashboard: Active Users")
    end
  end
end
