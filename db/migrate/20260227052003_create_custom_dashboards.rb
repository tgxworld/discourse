# frozen_string_literal: true

class CreateCustomDashboards < ActiveRecord::Migration[8.0]
  def change
    create_table :custom_dashboards do |t|
      t.integer :user_id, null: false
      t.string :title, limit: 255
      t.jsonb :data, null: false, default: {}
      t.integer :version, default: 0

      t.timestamps
    end

    add_index :custom_dashboards, :user_id, unique: true
    add_foreign_key :custom_dashboards, :users, column: :user_id, on_delete: :cascade
  end
end
