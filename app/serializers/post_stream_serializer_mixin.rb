require_dependency 'gap_serializer'
require_dependency 'post_serializer'
require_dependency 'timeline_lookup'

module PostStreamSerializerMixin
  def self.included(klass)
    klass.attributes :post_stream
    klass.attributes :timeline_lookup
  end

  def include_stream?
    true
  end

  def post_stream
    result = { posts: posts }

    if include_stream?
      result[:stream] = object.filtered_post_ids
      result[:stream_length] = result[:stream].length
      result[:first_post_id] = object.first_post_id
      result[:last_post_id] = object.last_post_id
    end

    result[:gaps] = GapSerializer.new(object.gaps, root: false) if object.gaps.present?
    result
  end

  def timeline_lookup
    TimelineLookup.build(object.filtered_post_stream)
  end

  def posts
    @posts ||= begin
      (object.posts || []).map do |post|
        post.topic = object.topic

        serializer = PostSerializer.new(post, scope: scope, root: false)
        serializer.add_raw = true if @options[:include_raw]
        serializer.topic_view = object

        serializer.as_json
      end
    end
  end

end
