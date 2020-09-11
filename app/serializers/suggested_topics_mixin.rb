# frozen_string_literal: true

module SuggestedTopicsMixin
  def self.included(klass)
    klass.attributes :related_messages,
                     :suggested_topics,
                     :new_messages_count,
                     :unread_messages_count
  end

  def include_related_messages?
    object.next_page.nil? && object.related_messages&.topics
  end

  def include_suggested_topics?
    object.next_page.nil? && object.suggested_topics&.topics
  end

  def include_new_messages_count?
    @include_new_messages_count ||= include_suggested_topics? && object.topic.private_message?
  end

  def include_unread_messages_count?
    include_new_messages_count?
  end

  def new_messages_count
    object.new_messages_count
  end

  def unread_messages_count
    object.unread_messages_count
  end

  def related_messages
    object.related_messages.topics.map do |t|
      SuggestedTopicSerializer.new(t, scope: scope, root: false)
    end
  end

  def suggested_topics
    object.suggested_topics.topics.map do |t|
      SuggestedTopicSerializer.new(t, scope: scope, root: false)
    end
  end
end
