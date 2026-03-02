import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import DMenu from "discourse/float-kit/components/d-menu";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import DashboardChartPreview from "./dashboard-chart-preview";

export default class DashboardAiSidebar extends Component {
  @service currentUser;
  @service messageBus;

  @tracked messages = [];
  @tracked inputText = "";
  @tracked loading = false;
  @tracked sending = false;
  @tracked streaming = false;
  @tracked error = null;
  @tracked topicId = null;
  @tracked conversations = null;
  @tracked loadingConversations = false;

  captureScrollContainer = modifier((element) => {
    this._scrollContainer = element;
  });

  _scrollContainer = null;
  _subscribed = false;
  _historyMenuApi = null;

  constructor() {
    super(...arguments);
    this.topicId = this.args.dashboard?.data?.conversationTopicId;
    if (this.topicId) {
      this.#loadMessages();
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.#unsubscribeFromStream();
  }

  get botPersona() {
    return this.currentUser.ai_enabled_personas?.find(
      (p) => p.name === "Dashboard Designer"
    );
  }

  get isAvailable() {
    return !!this.botPersona;
  }

  get inputDisabled() {
    return this.sending || this.streaming;
  }

  get lastMessageIsStreaming() {
    const last = this.messages[this.messages.length - 1];
    return last?.streaming;
  }

  parseMessageContent(cooked) {
    const chartRegex = /\[dashboard-chart\]([\s\S]*?)\[\/dashboard-chart\]/g;
    let match;
    const charts = [];
    let cleanedContent = cooked;

    while ((match = chartRegex.exec(cooked)) !== null) {
      try {
        const chartData = JSON.parse(match[1].trim());
        charts.push(chartData);
        cleanedContent = cleanedContent.replace(
          match[0],
          `<div class="dashboard-ai-sidebar__chart-placeholder" data-chart-index="${charts.length - 1}"></div>`
        );
      } catch {
        // Invalid JSON, leave as-is
      }
    }

    return { content: cleanedContent, charts };
  }

  @action
  scrollToBottom() {
    if (this._scrollContainer) {
      this._scrollContainer.scrollTop = this._scrollContainer.scrollHeight;
    }
  }

  @action
  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      this.sendMessage();
    }
  }

  @action
  updateInput(event) {
    this.inputText = event.target.value;
    event.target.style.height = "auto";
    event.target.style.height = `${Math.min(event.target.scrollHeight, 120)}px`;
  }

  @action
  onRegisterHistoryApi(api) {
    this._historyMenuApi = api;
  }

  @action
  async fetchConversations() {
    if (this.loadingConversations) {
      return;
    }

    this.loadingConversations = true;

    try {
      const result = await ajax("/discourse-ai/ai-bot/conversations.json", {
        data: { page: 0, per_page: 20 },
      });
      this.conversations = result.conversations;
    } catch {
      this.conversations = [];
    } finally {
      this.loadingConversations = false;
    }
  }

  @action
  async switchConversation(topicId) {
    this._historyMenuApi?.close();

    if (topicId === this.topicId) {
      return;
    }

    this.#unsubscribeFromStream();
    this.topicId = topicId;
    this.messages = [];
    this.streaming = false;
    this.error = null;

    await this.#persistConversationTopicId();
    await this.#loadMessages();
  }

  @action
  async startNewConversation() {
    this._historyMenuApi?.close();

    this.#unsubscribeFromStream();
    this.topicId = null;
    this.messages = [];
    this.streaming = false;
    this.error = null;

    await this.#persistConversationTopicId();
  }

  @action
  async sendMessage() {
    const text = this.inputText.trim();
    if (!text || this.inputDisabled) {
      return;
    }

    this.sending = true;
    this.inputText = "";
    this.error = null;

    this.messages = [
      ...this.messages,
      {
        id: `temp-${Date.now()}`,
        isUser: true,
        cooked: `<p>${this.#escapeHtml(text)}</p>`,
        charts: [],
      },
    ];

    requestAnimationFrame(() => this.scrollToBottom());

    try {
      if (!this.topicId) {
        await this.#createConversation(text);
      } else {
        await this.#replyToConversation(text);
      }
    } catch {
      this.error = i18n("admin.dashboard_v2.ai_sidebar.error");
    } finally {
      this.sending = false;
    }
  }

  @action
  async addChartToDashboard(chartData) {
    const message = `Please add this chart to my dashboard: "${chartData.title}" with chart type "${chartData.chart_type}"`;
    this.inputText = message;
    await this.sendMessage();
  }

  @bind
  onStreamMessage(data) {
    if (!data.post_id) {
      return;
    }

    this.streaming = !data.done;

    const existingIndex = this.messages.findIndex(
      (m) => m.id === data.post_id || m.id === `streaming-${data.post_id}`
    );

    const parsed = data.cooked
      ? this.parseMessageContent(data.cooked)
      : { content: "", charts: [] };

    const streamMsg = {
      id: data.post_id,
      isUser: false,
      cooked: parsed.content,
      charts: parsed.charts,
      streaming: !data.done,
    };

    if (existingIndex >= 0) {
      const updated = [...this.messages];
      updated[existingIndex] = streamMsg;
      this.messages = updated;
    } else {
      this.messages = [...this.messages, streamMsg];
    }

    requestAnimationFrame(() => this.scrollToBottom());

    if (data.done) {
      this.#loadMessages();
    }
  }

  async #createConversation(text) {
    const persona = this.botPersona;
    if (!persona) {
      return;
    }

    const response = await ajax("/posts.json", {
      method: "POST",
      data: {
        raw: text,
        title: `Dashboard Assistant - ${new Date().toLocaleDateString()}`,
        archetype: "private_message",
        target_recipients: persona.username,
        meta_data: { ai_persona_id: persona.id },
      },
    });

    this.topicId = response.topic_id;
    this.#subscribeToStream();
    await this.#persistConversationTopicId();

    this.streaming = true;
    await this.#loadMessages();
  }

  async #replyToConversation(text) {
    await ajax("/posts.json", {
      method: "POST",
      data: {
        raw: text,
        topic_id: this.topicId,
      },
    });

    this.streaming = true;
  }

  async #persistConversationTopicId() {
    if (!this.args.dashboard) {
      return;
    }

    const existingData = this.args.dashboard.data || {};
    const data = { ...existingData, conversationTopicId: this.topicId };
    await ajax("/admin/dashboard-v2.json", {
      method: "PUT",
      data: { data: JSON.stringify(data) },
    });
  }

  async #loadMessages() {
    if (!this.topicId) {
      return;
    }

    this.loading = !this.messages.length;

    try {
      const result = await ajax(`/t/${this.topicId}.json`);
      const posts = result.post_stream?.posts || [];

      this.messages = posts.map((post) => {
        const isUser = post.user_id === this.currentUser.id;
        const parsed = this.parseMessageContent(post.cooked || "");
        return {
          id: post.id,
          isUser,
          cooked: parsed.content,
          charts: parsed.charts,
          username: post.username,
        };
      });

      if (!this._subscribed) {
        this.#subscribeToStream();
      }

      requestAnimationFrame(() => this.scrollToBottom());
    } catch {
      this.error = i18n("admin.dashboard_v2.ai_sidebar.error");
    } finally {
      this.loading = false;
    }
  }

  #subscribeToStream() {
    if (!this.topicId || this._subscribed) {
      return;
    }
    this._subscribed = true;
    this.messageBus.subscribe(
      `discourse-ai/ai-bot/topic/${this.topicId}`,
      this.onStreamMessage
    );
  }

  #unsubscribeFromStream() {
    if (this.topicId && this._subscribed) {
      this.messageBus.unsubscribe(
        `discourse-ai/ai-bot/topic/${this.topicId}`,
        this.onStreamMessage
      );
    }
    this._subscribed = false;
  }

  #escapeHtml(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }

  <template>
    <div class="dashboard-ai-sidebar">
      <div class="dashboard-ai-sidebar__header">
        {{#if @onShowQueries}}
          <DButton
            @action={{@onShowQueries}}
            @icon="arrow-left"
            @title={{i18n "admin.dashboard_v2.ai_sidebar.back_to_queries"}}
            class="btn-flat btn-icon no-text dashboard-ai-sidebar__back-btn"
          />
        {{/if}}
        <h3>{{i18n "admin.dashboard_v2.ai_sidebar.title"}}</h3>
        {{#if this.isAvailable}}
          <DMenu
            @icon="clock-rotate-left"
            @identifier="ai-sidebar-history"
            @onRegisterApi={{this.onRegisterHistoryApi}}
            @onShow={{this.fetchConversations}}
            @triggerClass="btn-flat btn-icon no-text dashboard-ai-sidebar__history-trigger"
            @title={{i18n "admin.dashboard_v2.ai_sidebar.history.title"}}
          >
            <:content>
              <DropdownMenu as |dropdown|>
                <dropdown.item>
                  <DButton
                    @action={{this.startNewConversation}}
                    @icon="plus"
                    @translatedLabel={{i18n
                      "admin.dashboard_v2.ai_sidebar.history.new_conversation"
                    }}
                    class="btn-transparent dashboard-ai-sidebar__history-new"
                  />
                </dropdown.item>
                <dropdown.divider />
                {{#if this.loadingConversations}}
                  <li class="dashboard-ai-sidebar__history-loading">
                    <ConditionalLoadingSpinner @condition={{true}} />
                  </li>
                {{else if this.conversations.length}}
                  {{#each this.conversations as |convo|}}
                    <dropdown.item>
                      <DButton
                        @action={{fn this.switchConversation convo.id}}
                        class={{if
                          (eq convo.id this.topicId)
                          "btn-transparent dashboard-ai-sidebar__history-item is-selected"
                          "btn-transparent dashboard-ai-sidebar__history-item"
                        }}
                      >
                        <span
                          class="dashboard-ai-sidebar__history-item-title"
                        >{{convo.title}}</span>
                        <span
                          class="dashboard-ai-sidebar__history-item-date"
                        >{{formatDate
                            convo.last_posted_at
                            format="tiny"
                          }}</span>
                      </DButton>
                    </dropdown.item>
                  {{/each}}
                {{else}}
                  <li class="dashboard-ai-sidebar__history-empty">
                    {{icon "comments"}}
                    <span>{{i18n
                        "admin.dashboard_v2.ai_sidebar.history.empty"
                      }}</span>
                  </li>
                {{/if}}
              </DropdownMenu>
            </:content>
          </DMenu>
        {{/if}}
      </div>

      {{#if this.isAvailable}}
        <div
          class="dashboard-ai-sidebar__messages"
          {{this.captureScrollContainer}}
        >
          <ConditionalLoadingSpinner @condition={{this.loading}}>
            {{#if this.messages.length}}
              {{#each this.messages as |msg|}}
                <div
                  class="dashboard-ai-sidebar__message
                    {{if
                      msg.isUser
                      'dashboard-ai-sidebar__message--user'
                      'dashboard-ai-sidebar__message--bot'
                    }}"
                >
                  <div class="dashboard-ai-sidebar__message-content">
                    {{htmlSafe msg.cooked}}
                  </div>
                  {{#each msg.charts as |chart|}}
                    <DashboardChartPreview
                      @chartData={{chart}}
                      @onAddToDashboard={{this.addChartToDashboard}}
                    />
                  {{/each}}
                  {{#if msg.streaming}}
                    <div class="dashboard-ai-sidebar__typing-indicator">
                      <span></span><span></span><span></span>
                    </div>
                  {{/if}}
                </div>
              {{/each}}
              {{#if this.streaming}}
                {{#unless this.lastMessageIsStreaming}}
                  <div class="dashboard-ai-sidebar__thinking">
                    {{i18n "admin.dashboard_v2.ai_sidebar.loading"}}
                  </div>
                {{/unless}}
              {{/if}}
            {{else}}
              <div class="dashboard-ai-sidebar__empty">
                {{i18n "admin.dashboard_v2.ai_sidebar.empty_conversation"}}
              </div>
            {{/if}}
          </ConditionalLoadingSpinner>
        </div>

        {{#if this.error}}
          <div class="dashboard-ai-sidebar__error">
            {{this.error}}
          </div>
        {{/if}}

        <div class="dashboard-ai-sidebar__input">
          <textarea
            class="dashboard-ai-sidebar__textarea"
            placeholder={{i18n "admin.dashboard_v2.ai_sidebar.placeholder"}}
            disabled={{this.inputDisabled}}
            value={{this.inputText}}
            {{on "input" this.updateInput}}
            {{on "keydown" this.handleKeydown}}
          />
        </div>
      {{else}}
        <div class="dashboard-ai-sidebar__unavailable">
          {{i18n "admin.dashboard_v2.ai_sidebar.ai_not_available"}}
        </div>
      {{/if}}
    </div>
  </template>
}
