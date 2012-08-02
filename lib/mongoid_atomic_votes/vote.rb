class Mongoid::AtomicVotes::Vote
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  embedded_in :atomic_voteable, polymorphic: true

  field :value,       type: Integer
  field :voted_by_id, type: Moped::BSON::ObjectId
  field :voter_type,  type: String

  validates_presence_of  :value, :voted_by_id, :voter_type
  validates_inclusion_of :value, in: ->(vote){ vote.class.vote_range }, if: ->(vote){ vote.class.vote_range }

  index({voted_by_id: 1, mark: 1}, {unique: true, background: true})

  class << self
    @@vote_range = nil

    def set_vote_range(val)
      @@vote_range ||= val
    end

    def vote_range
      @@vote_range
    end
  end
end