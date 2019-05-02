module Jobs
  class CreateOptimizedImage < Jobs::Base
    sidekiq_options queue: 'low'

    def execute(args)
      return if Rails.env.test?

      %i{width height upload_id}.each do |attr|
        raise Discourse::InvalidParameters.new(:attr) unless args[attr]
      end

      return unless upload = Upload.find_by(id: args[:upload_id])

      upload.create_thumbnail!(args[:width], args[:height])
    end
  end
end
