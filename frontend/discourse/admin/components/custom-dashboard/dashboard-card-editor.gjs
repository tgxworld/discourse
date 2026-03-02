import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import AceEditor from "discourse/components/ace-editor";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class DashboardCardEditor extends Component {
  @tracked loading = true;
  @tracked saving = false;
  @tracked title = "";
  @tracked sql = "";
  @tracked queryId = null;

  constructor() {
    super(...arguments);
    this.title = this.args.model.panel.title || "";
    this.#loadQuery();
  }

  async #loadQuery() {
    try {
      const response = await ajax(
        `/admin/plugins/explorer/queries/${this.args.model.panel.source}.json`
      );
      const query = response.query;
      this.queryId = query.id;
      this.sql = query.sql;
      this._originalSql = query.sql;
    } catch {
      this.sql = "";
      this._originalSql = "";
    } finally {
      this.loading = false;
    }
  }

  @action
  onTitleInput(event) {
    this.title = event.target.value;
  }

  @action
  onSqlChange(value) {
    this.sql = value;
  }

  @action
  async save() {
    this.saving = true;

    try {
      if (this.sql !== this._originalSql && this.queryId) {
        await ajax(`/admin/plugins/explorer/queries/${this.queryId}`, {
          type: "PUT",
          data: { query: { sql: this.sql } },
        });
      }

      this.args.closeModal({
        title: this.title,
        sqlChanged: this.sql !== this._originalSql,
      });
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <DModal
      @title={{i18n "admin.dashboard_v2.card_editor.title"}}
      @closeModal={{@closeModal}}
      class="dashboard-card-editor"
    >
      <:body>
        <ConditionalLoadingSpinner @condition={{this.loading}}>
          <div class="dashboard-card-editor__field">
            <label class="dashboard-card-editor__label">
              {{i18n "admin.dashboard_v2.card_editor.card_title"}}
            </label>
            <input
              type="text"
              class="dashboard-card-editor__title-input"
              value={{this.title}}
              {{on "input" this.onTitleInput}}
            />
          </div>

          <div class="dashboard-card-editor__field">
            <label class="dashboard-card-editor__label">
              {{i18n "admin.dashboard_v2.card_editor.sql"}}
            </label>
            <div class="dashboard-card-editor__sql-editor">
              <AceEditor
                @content={{this.sql}}
                @onChange={{this.onSqlChange}}
                @mode="sql"
              />
            </div>
          </div>
        </ConditionalLoadingSpinner>
      </:body>

      <:footer>
        <DButton
          @action={{this.save}}
          @label="admin.dashboard_v2.card_editor.save"
          @disabled={{this.saving}}
          class="btn-primary"
        />
        <DButton
          @action={{@closeModal}}
          @label="admin.dashboard_v2.card_editor.cancel"
          class="btn-default"
        />
      </:footer>
    </DModal>
  </template>
}
