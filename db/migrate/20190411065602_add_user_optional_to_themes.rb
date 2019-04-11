class AddUserOptionalToThemes < ActiveRecord::Migration[5.2]
  def change
    add_column :themes, :user_optional, :boolean, default: false, null: false
  end
end
