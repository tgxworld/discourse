import { ajax } from "discourse/lib/ajax";

export default class CustomDashboard {
  static async fetch() {
    const json = await ajax("/admin/dashboard-v2.json");
    return json;
  }

  static async save(data) {
    return await ajax("/admin/dashboard-v2.json", {
      type: "PUT",
      data: { data: JSON.stringify(data) },
    });
  }
}
