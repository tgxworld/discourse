# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::RunDataExplorerQuery do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  let(:progress_blk) { Proc.new {} }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  describe "#invoke" do
    it "executes SQL and returns columns, rows, chart_type, and title" do
      pg_result = instance_double(PG::Result)
      allow(pg_result).to receive(:fields).and_return(%w[user_count created_date])
      allow(pg_result).to receive(:values).and_return([[10, "2025-01-01"], [20, "2025-01-02"]])
      allow(pg_result).to receive(:ntuples).and_return(2)
      allow(pg_result).to receive(:check)

      allow(DiscourseDataExplorer::DataExplorer).to receive(:run_query).and_return(
        { error: nil, pg_result: pg_result, duration_secs: 0.01 },
      )

      tool =
        described_class.new(
          {
            sql:
              "SELECT COUNT(*) as user_count, created_at::date as created_date FROM users GROUP BY created_date",
            chart_type: "line",
            title: "Users Over Time",
          },
          bot_user: bot_user,
          llm: llm,
        )

      result = tool.invoke(&progress_blk)

      expect(result[:columns]).to eq(%w[user_count created_date])
      expect(result[:rows]).to eq([[10, "2025-01-01"], [20, "2025-01-02"]])
      expect(result[:chart_type]).to eq("line")
      expect(result[:title]).to eq("Users Over Time")
    end

    it "sets custom_raw with a dashboard-chart bbcode block" do
      pg_result = instance_double(PG::Result)
      allow(pg_result).to receive(:fields).and_return(%w[count date])
      allow(pg_result).to receive(:values).and_return([[5, "2025-03-01"]])
      allow(pg_result).to receive(:ntuples).and_return(1)
      allow(pg_result).to receive(:check)

      allow(DiscourseDataExplorer::DataExplorer).to receive(:run_query).and_return(
        { error: nil, pg_result: pg_result, duration_secs: 0.01 },
      )

      tool =
        described_class.new(
          {
            sql: "SELECT COUNT(*) as count, created_at::date as date FROM topics GROUP BY date",
            chart_type: "bar",
            title: "Topics Per Day",
          },
          bot_user: bot_user,
          llm: llm,
        )

      tool.invoke(&progress_blk)

      expect(tool.custom_raw).to include("[dashboard-chart]")
      expect(tool.custom_raw).to include("[/dashboard-chart]")
      expect(tool.custom_raw).to include("Topics Per Day")
      expect(tool.custom_raw).to include("bar")
    end

    it "rejects SQL containing semicolons" do
      tool =
        described_class.new(
          { sql: "SELECT 1; DROP TABLE users", chart_type: "table", title: "Bad Query" },
          bot_user: bot_user,
          llm: llm,
        )

      result = tool.invoke(&progress_blk)

      expect(result[:error]).to be_present
    end

    it "handles empty result sets" do
      pg_result = instance_double(PG::Result)
      allow(pg_result).to receive(:fields).and_return(%w[id name])
      allow(pg_result).to receive(:values).and_return([])
      allow(pg_result).to receive(:ntuples).and_return(0)
      allow(pg_result).to receive(:check)

      allow(DiscourseDataExplorer::DataExplorer).to receive(:run_query).and_return(
        { error: nil, pg_result: pg_result, duration_secs: 0.01 },
      )

      tool =
        described_class.new(
          {
            sql: "SELECT id, name FROM users WHERE id < 0",
            chart_type: "table",
            title: "No Results",
          },
          bot_user: bot_user,
          llm: llm,
        )

      result = tool.invoke(&progress_blk)

      expect(result[:columns]).to eq(%w[id name])
      expect(result[:rows]).to eq([])
    end
  end
end
