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

    dashboard.data = dashboard_params[:data] if dashboard_params[:data].present?
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

  def dashboard_params
    params.permit(data: {})
  end
end
