class Mongoid::AtomicVotes::Vote
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  embedded_in :atomic_voteable, polymorphic: true

  field :value, type: Integer
  field :voted_by_id, type: BSON::ObjectId
  field :voter_type, type: String

  validates_presence_of :value, :voted_by_id, :voter_type
  validates_inclusion_of :value,
                         in: ->(vote) { vote.atomic_voteable.class.vote_range },
                         if: ->(vote) { vote.atomic_voteable.class.vote_range }

  index({ voted_by_id: 1, mark: 1 }, unique: true, background: true)
end
