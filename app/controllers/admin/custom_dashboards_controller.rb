# frozen_string_literal: true

class Admin::CustomDashboardsController < Admin::AdminController
  def show
    respond_to do |format|
      format.html { render body: nil }
      format.json do
        dashboard = CustomDashboard.find_or_create_for(current_user)

        render json: {
                 id: dashboard.id,
                 title: dashboard.title,
                 data: dashboard.data,
                 version: dashboard.version,
               }
      end
    end
  end

  def update
    dashboard = CustomDashboard.find_or_create_for(current_user)

    if params[:version].present? && params[:version].to_i != dashboard.version
      return render json: failed_json.merge(error: "Version conflict"), status: :conflict
    end

    dashboard.data = parsed_data if parsed_data.present?
    dashboard.version = dashboard.version + 1

    if dashboard.save
      render json: {
               id: dashboard.id,
               title: dashboard.title,
               data: dashboard.data,
               version: dashboard.version,
             }
    else
      render_json_error(dashboard)
    end
  end

  private

  def parsed_data
    return @parsed_data if defined?(@parsed_data)
    raw = params[:data]
    @parsed_data = raw.is_a?(String) ? JSON.parse(raw) : raw&.to_unsafe_h
  rescue JSON::ParserError
    @parsed_data = nil
  end
end
