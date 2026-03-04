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

  def stub_query_result(fields:, values:)
    pg_result = instance_double(PG::Result)
    allow(pg_result).to receive(:fields).and_return(fields)
    allow(pg_result).to receive(:values).and_return(values)
    allow(pg_result).to receive(:ntuples).and_return(values.length)
    allow(pg_result).to receive(:check)
    allow(DiscourseDataExplorer::DataExplorer).to receive(:run_query).and_return(
      { error: nil, pg_result: pg_result, duration_secs: 0.01 },
    )
  end

  describe "#invoke" do
    it "executes a single query and returns datasets" do
      stub_query_result(
        fields: %w[created_date user_count],
        values: [["2025-01-01", 10], ["2025-01-02", 20]],
      )

      sql =
        "SELECT created_at::date as created_date, COUNT(*) as user_count FROM users GROUP BY created_date"
      queries = [{ sql: sql, label: "Users", style: "solid" }].to_json

      tool =
        described_class.new(
          { queries: queries, chart_type: "line", title: "Users Over Time" },
          bot_user: bot_user,
          llm: llm,
        )

      result = tool.invoke(&progress_blk)

      expect(result[:datasets].length).to eq(1)
      expect(result[:datasets][0][:label]).to eq("Users")
      expect(result[:datasets][0][:rows]).to eq([["2025-01-01", 10], ["2025-01-02", 20]])
      expect(result[:chart_type]).to eq("line")
      expect(result[:title]).to eq("Users Over Time")
      expect(result[:sql]).to include(sql)
    end

    it "executes multiple queries for comparison charts" do
      call_count = 0
      allow(DiscourseDataExplorer::DataExplorer).to receive(:run_query) do
        call_count += 1
        pg_result = instance_double(PG::Result)
        if call_count == 1
          allow(pg_result).to receive(:fields).and_return(%w[day count])
          allow(pg_result).to receive(:values).and_return([[1, 50], [2, 60]])
        else
          allow(pg_result).to receive(:fields).and_return(%w[day count])
          allow(pg_result).to receive(:values).and_return([[1, 30], [2, 40]])
        end
        allow(pg_result).to receive(:ntuples).and_return(2)
        allow(pg_result).to receive(:check)
        { error: nil, pg_result: pg_result, duration_secs: 0.01 }
      end

      queries = [
        { sql: "SELECT day, count FROM this_month", label: "This Month", style: "solid" },
        { sql: "SELECT day, count FROM last_month", label: "Last Month", style: "dashed" },
      ].to_json

      tool =
        described_class.new(
          { queries: queries, chart_type: "line", title: "Monthly Comparison" },
          bot_user: bot_user,
          llm: llm,
        )

      result = tool.invoke(&progress_blk)

      expect(result[:datasets].length).to eq(2)
      expect(result[:datasets][0][:label]).to eq("This Month")
      expect(result[:datasets][0][:style]).to eq("solid")
      expect(result[:datasets][1][:label]).to eq("Last Month")
      expect(result[:datasets][1][:style]).to eq("dashed")
    end

    it "sets custom_raw with a data-explorer-chart bbcode block" do
      stub_query_result(fields: %w[count date], values: [[5, "2025-03-01"]])

      sql = "SELECT COUNT(*) as count, created_at::date as date FROM topics GROUP BY date"
      queries = [{ sql: sql, label: "Topics" }].to_json

      tool =
        described_class.new(
          { queries: queries, chart_type: "bar", title: "Topics Per Day" },
          bot_user: bot_user,
          llm: llm,
        )

      tool.invoke(&progress_blk)

      expect(tool.custom_raw).to include("[data-explorer-chart]")
      expect(tool.custom_raw).to include("[/data-explorer-chart]")
      expect(tool.custom_raw).to include("Topics Per Day")
      expect(tool.custom_raw).to include(sql)
    end

    it "rejects SQL containing semicolons" do
      queries = [{ sql: "SELECT 1; DROP TABLE users", label: "Bad" }].to_json

      tool =
        described_class.new(
          { queries: queries, chart_type: "bar", title: "Bad Query" },
          bot_user: bot_user,
          llm: llm,
        )

      result = tool.invoke(&progress_blk)
      expect(result[:error]).to be_present
    end

    it "rejects invalid JSON for queries" do
      tool =
        described_class.new(
          { queries: "not valid json", chart_type: "bar", title: "Bad" },
          bot_user: bot_user,
          llm: llm,
        )

      result = tool.invoke(&progress_blk)
      expect(result[:error]).to be_present
    end
  end
end
