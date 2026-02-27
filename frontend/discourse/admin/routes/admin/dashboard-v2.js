import Route from "@ember/routing/route";
import CustomDashboard from "discourse/admin/models/custom-dashboard";

export default class AdminDashboardV2Route extends Route {
  async model() {
    return await CustomDashboard.fetch();
  }
}
