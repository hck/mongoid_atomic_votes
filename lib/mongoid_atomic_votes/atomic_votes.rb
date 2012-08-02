module Mongoid
  module AtomicVotes
    def self.included(base)
      base.field :vote_count, type: Integer, default: 0
      base.field :vote_value, type: Float,   default: nil

      base.embeds_many :votes, class_name: 'Mongoid::AtomicVotes::Vote', as: :atomic_voteable

      base.scope :not_voted,     base.where(:vote_value.exists => false)
      base.scope :voted,         base.where(:vote_value.exists => true)
      base.scope :voted_by,      ->(resource) { base.where('votes.voted_by_id' => resource.id, 'votes.voter_type' => resource.class.name) }
      base.scope :vote_value_in, ->(range)    { base.where(:vote_value.gte => range.begin, :vote_value.lte => range.end) }
      base.scope :highest_voted, ->(limit=10) { base.order_by(:vote_value.desc).limit(limit) }

      base.extend ClassMethods
    end

    def vote(value, voted_by)
      mark = Vote.new(value: value, voted_by_id: voted_by.id, voter_type: voted_by.class.name)
      return false unless mark.valid?

      _assigning do
        self.votes << mark
        self.vote_value = (self.vote_count * (self.vote_value || 0) + value).to_f / (self.vote_count + 1)
        self.vote_count += 1
      end

      self.collection.
        find({_id: self.id}).
        update('$inc' => {vote_count: 1}, '$set' => {vote_value: self.vote_value}, '$push' => {votes: mark.as_json}).nil?
    end

    def retract(voted_by)
      mark = self.votes.find_by(voted_by_id: voted_by.id)
      return false unless mark

      _assigning do
        self.votes.reject!{|v| v.id == mark.id}
        self.vote_value = self.vote_count == 1 ? 0 : (self.vote_value * self.vote_count - mark.value) / (self.vote_count - 1)
        self.vote_count -= 1
      end

      self.collection.
        find({_id: self.id}).
        update('$inc' => {vote_count: -1}, '$set' => {vote_value: vote_value}, '$pull' => {votes: {_id: mark.id}}).nil?
    end

    def has_votes?
      self.vote_count > 0
    end

    def voted_by?(voted_by)
      !!self.votes.find_by(voted_by_id: voted_by.id)
    rescue
      false
    end

    module ClassMethods
      def set_vote_range(val)
        raise 'argument should be a Range' unless val.is_a?(Range)
        Vote.send(__method__, val)
      end
    end
  end
end