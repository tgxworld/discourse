# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class AddCardToDashboard < Tool
        DEFAULT_PANEL_WIDTH = 6
        DEFAULT_PANEL_HEIGHT = 4
        GRID_COLUMNS = 12

        def self.signature
          {
            name: name,
            description:
              "Adds a new card (chart or table) to the user's custom dashboard. " \
                "Creates a Data Explorer query and appends a panel to the dashboard.",
            parameters: [
              {
                name: "sql",
                description:
                  "The SQL query to execute for this dashboard card. Must be a single SELECT statement.",
                type: "string",
                required: true,
              },
              {
                name: "title",
                description: "A descriptive title for the dashboard card.",
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
                name: "param_definitions",
                description:
                  "Optional parameter definitions for the query, e.g. 'start_date:date end_date:date'.",
                type: "string",
              },
            ],
          }
        end

        def self.name
          "add_card_to_dashboard"
        end

        def sql
          parameters[:sql]
        end

        def title
          parameters[:title]
        end

        def chart_type
          parameters[:chart_type]
        end

        def param_definitions
          parameters[:param_definitions]
        end

        def invoke
          query_title = "Dashboard: #{title}"

          query =
            DiscourseDataExplorer::Query.create!(
              name: query_title,
              sql: sql,
              user_id: context.user.id,
            )

          panel_id = SecureRandom.hex(8)
          retried = false

          begin
            dashboard = CustomDashboard.find_or_create_for(context.user)
            loaded_version = dashboard.version

            grid_pos = compute_next_grid_position(dashboard.data["panels"] || [])

            panel = {
              "id" => panel_id,
              "chartType" => chart_type,
              "queryId" => query.id,
              "gridPos" => grid_pos,
            }

            panel["paramDefinitions"] = param_definitions if param_definitions.present?

            panels = (dashboard.data["panels"] || []) + [panel]
            new_data = dashboard.data.merge("panels" => panels)

            rows_updated =
              CustomDashboard.where(id: dashboard.id, version: loaded_version).update_all(
                data: new_data,
                version: loaded_version + 1,
              )

            raise ActiveRecord::StaleObjectError.new(dashboard, "update") if rows_updated == 0
          rescue ActiveRecord::StaleObjectError
            raise if retried
            retried = true
            retry
          end

          { status: "success", query_id: query.id, panel_id: panel_id, title: query_title }
        end

        protected

        def description_args
          { title: title }
        end

        private

        def compute_next_grid_position(panels)
          if panels.empty?
            return({ "x" => 0, "y" => 0, "w" => DEFAULT_PANEL_WIDTH, "h" => DEFAULT_PANEL_HEIGHT })
          end

          # Try placing next to the last panel on the same row
          last_panel = panels.last
          last_pos = last_panel["gridPos"]
          next_x = last_pos["x"] + last_pos["w"]

          if next_x + DEFAULT_PANEL_WIDTH <= GRID_COLUMNS
            return(
              {
                "x" => next_x,
                "y" => last_pos["y"],
                "w" => DEFAULT_PANEL_WIDTH,
                "h" => DEFAULT_PANEL_HEIGHT,
              }
            )
          end

          # Move to next row
          max_y_bottom = panels.map { |p| p["gridPos"]["y"] + p["gridPos"]["h"] }.max

          { "x" => 0, "y" => max_y_bottom, "w" => DEFAULT_PANEL_WIDTH, "h" => DEFAULT_PANEL_HEIGHT }
        end
      end
    end
  end
end
