# frozen_string_literal: true

class PollVote < ActiveRecord::Base
  belongs_to :poll
  belongs_to :poll_option
  belongs_to :user
end

# == Schema Information
#
# Table name: poll_votes
#
#  poll_id        :bigint(8)
#  poll_option_id :bigint(8)
#  user_id        :bigint(8)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_poll_votes_on_poll_id                                 (poll_id)
#  index_poll_votes_on_poll_id_and_poll_option_id_and_user_id  (poll_id,poll_option_id,user_id) UNIQUE
#  index_poll_votes_on_poll_option_id                          (poll_option_id)
#  index_poll_votes_on_user_id                                 (user_id)
#
