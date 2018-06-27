module TimelineLookup

  # Given an array containing days_ago, return at most `max_values` worth of a
  # lookup table to help the front end timeline display dates associated with posts
  def self.build(array, max_values = 300)
    result = []

    every = (array.size.to_f / max_values).ceil

    last_days_ago = -1
    array.each_with_index do |days_ago, idx|
      next unless (idx % every) === 0

      if (days_ago != last_days_ago)
        result << [idx + 1, days_ago]
        last_days_ago = days_ago
      end

    end

    result
  end

end
