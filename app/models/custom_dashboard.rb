# frozen_string_literal: true

class CustomDashboard < ActiveRecord::Base
  belongs_to :user

  validates :data, presence: true

  def self.find_or_create_for(user)
    find_or_create_by(user: user) do |dashboard|
      dashboard.title = "My Dashboard"
      dashboard.data = { "panels" => [] }
    end
  end
end
