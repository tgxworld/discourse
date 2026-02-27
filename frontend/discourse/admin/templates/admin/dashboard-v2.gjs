import DashboardV2 from "discourse/admin/components/custom-dashboard/dashboard-v2";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="admin-dashboard-v2 admin-config-page">
    <DPageHeader
      @titleLabel={{i18n "admin.dashboard_v2.title"}}
      @descriptionLabel={{i18n "admin.dashboard_v2.description"}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin/dashboard-v2"
          @label={{i18n "admin.dashboard_v2.title"}}
        />
      </:breadcrumbs>
    </DPageHeader>

    <div class="admin-container admin-config-page__main-area">
      <DashboardV2 @dashboard={{@model}} />
    </div>
  </div>
</template>
