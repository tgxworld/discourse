# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class RunDataExplorerQuery < Tool
        def self.signature
          {
            name: name,
            description:
              "Executes one or more read-only SQL queries and renders the results as a chart. " \
                "Use a single query for simple charts, or multiple queries to overlay datasets " \
                "(e.g., comparing two time periods on the same chart).",
            parameters: [
              {
                name: "queries",
                description:
                  'JSON array of query objects. Each object: {"sql": "SELECT ...", "label": "Dataset Name", "style": "solid|dashed"}. ' \
                    "The first column of each query is used as labels (x-axis), the second as values (y-axis). " \
                    "For multi-dataset comparison charts, all queries should return the same label column values for alignment. " \
                    "Style defaults to solid. Use dashed for comparison/previous-period datasets.",
                type: "string",
                required: true,
              },
              {
                name: "chart_type",
                description: "The type of chart to render: line, bar, pie, or area.",
                type: "string",
                required: true,
                enum: %w[line bar pie area],
              },
              {
                name: "title",
                description: "A descriptive title for the chart.",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "run_data_explorer_query"
        end

        def queries
          parameters[:queries]
        end

        def chart_type
          parameters[:chart_type]
        end

        def title
          parameters[:title]
        end

        def invoke
          parsed_queries =
            begin
              JSON.parse(queries)
            rescue JSON::ParserError
              return { error: "queries must be a valid JSON array." }
            end

          parsed_queries = [parsed_queries] if parsed_queries.is_a?(Hash)
          return { error: "queries must be an array." } unless parsed_queries.is_a?(Array)
          return { error: "queries must not be empty." } if parsed_queries.empty?

          datasets = []
          all_sql = []

          parsed_queries.each_with_index do |q, idx|
            sql = q["sql"].to_s
            label = q["label"] || "Dataset #{idx + 1}"
            style = q["style"] || "solid"

            if sql.include?(";")
              return(
                {
                  error:
                    "Query #{idx + 1} must not contain semicolons. Use a single SELECT statement.",
                }
              )
            end

            query = DiscourseDataExplorer::Query.new(name: "#{title} - #{label}", sql: sql)
            result = DiscourseDataExplorer::DataExplorer.run_query(query)

            return { error: "Query #{idx + 1}: #{result[:error].message}" } if result[:error]

            pg_result = result[:pg_result]

            datasets << {
              label: label,
              style: style,
              columns: pg_result.fields,
              rows: pg_result.values,
            }

            all_sql << "-- #{label}\n#{sql}"
          end

          chart_data = {
            datasets: datasets,
            chart_type: chart_type,
            title: title,
            sql: all_sql.join("\n\n"),
          }

          self.custom_raw =
            "\n[data-explorer-chart]\n#{chart_data.to_json}\n[/data-explorer-chart]\n"

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
