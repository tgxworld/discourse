# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class RunDataExplorerQuery < Tool
        def self.signature
          {
            name: name,
            description:
              "Executes a read-only SQL query against the database and returns the results. " \
                "Use this to fetch data for dashboard charts and tables.",
            parameters: [
              {
                name: "sql",
                description:
                  "The SQL query to execute. Must be a single SELECT statement without semicolons.",
                type: "string",
                required: true,
              },
              {
                name: "chart_type",
                description: "The type of chart to render: line, bar, pie, area, or table.",
                type: "string",
                required: true,
                enum: %w[line bar pie area table],
              },
              {
                name: "title",
                description: "A descriptive title for the chart or table.",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "run_data_explorer_query"
        end

        def sql
          parameters[:sql]
        end

        def chart_type
          parameters[:chart_type]
        end

        def title
          parameters[:title]
        end

        def invoke
          if sql.include?(";")
            return { error: "SQL must not contain semicolons. Use a single SELECT statement." }
          end

          query = DiscourseDataExplorer::Query.new(name: title, sql: sql)

          result = DiscourseDataExplorer::DataExplorer.run_query(query)

          return { error: result[:error].message } if result[:error]

          pg_result = result[:pg_result]
          columns = pg_result.fields
          rows = pg_result.values

          chart_data = { columns: columns, rows: rows, chart_type: chart_type, title: title }

          self.custom_raw = "[dashboard-chart]\n#{chart_data.to_json}\n[/dashboard-chart]"

          chart_data
        end

        protected

        def description_args
          { title: title }
        end
      end
    end
  end
end
