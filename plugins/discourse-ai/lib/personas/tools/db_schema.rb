# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class DbSchema < Tool
        def self.signature
          {
            name: name,
            description: "Will load schema information for specific tables in the database",
            parameters: [
              {
                name: "tables",
                description:
                  "list of tables to load schema information for, comma separated list eg: (users,posts))",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "schema"
        end

        def tables
          parameters[:tables]
        end

        def invoke
          tables_arr = tables.split(",").map(&:strip)

          table_info = {}
          DB
            .query(<<~SQL, tables_arr)
            select table_name, column_name, data_type from information_schema.columns
            where table_schema = 'public'
            and table_name in (?)
            order by table_name
          SQL
            .each do |row|
              (table_info[row.table_name] ||= []) << "#{row.column_name} #{row.data_type}"
            end

          index_info = {}
          DB
            .query(<<~SQL, tables_arr)
            select tablename, indexname, indexdef from pg_indexes
            where schemaname = 'public'
            and tablename in (?)
            order by tablename, indexname
          SQL
            .each { |row| (index_info[row.tablename] ||= []) << row.indexdef }

          schema_info =
            table_info
              .map do |table_name, columns|
                result = +"#{table_name}(#{columns.join(",")})"
                if index_info[table_name].present?
                  result << "\nIndexes:\n"
                  result << index_info[table_name].map { |indexdef| "  #{indexdef}" }.join("\n")
                end
                result
              end
              .join("\n")

          { schema_info: schema_info, tables: tables }
        end

        protected

        def description_args
          { tables: tables }
        end
      end
    end
  end
end
