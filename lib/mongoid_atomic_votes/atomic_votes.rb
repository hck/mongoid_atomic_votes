module Mongoid
  module AtomicVotes
    class << self
      def included(base)
        define_relations(base)
        define_scopes(base)

        base.extend ClassMethods
      end

      private
      def define_relations(base)
        base.field :vote_count, type: Integer, default: 0
        base.field :vote_value, type: Float, default: nil

        base.embeds_many :votes, class_name: 'Mongoid::AtomicVotes::Vote', as: :atomic_voteable
      end

      def define_scopes(base)
        base.scope :not_voted, -> { base.where(:vote_value.exists => false) }

        base.scope :voted, -> { base.where(:vote_value.exists => true) }

        base.scope :voted_by, ->(resource) do
          base.where('votes.voted_by_id' => resource.id, 'votes.voter_type' => resource.class.name)
        end

        base.scope :vote_value_in, ->(range) do
          base.where(:vote_value.gte => range.begin, :vote_value.lte => range.end)
        end

        base.scope :highest_voted, ->(limit=10) { base.order_by(:vote_value.desc).limit(limit) }
      end
    end

    def vote(value, voted_by)
      mark = Vote.new(value: value, voted_by_id: voted_by.id, voter_type: voted_by.class.name)
      add_vote_mark(mark)
    end

    def retract(voted_by)
      mark = self.votes.find_by(voted_by_id: voted_by.id)
      mark && remove_vote_mark(mark)
    end

    def has_votes?
      self.vote_count > 0
    end

    def voted_by?(voted_by)
      !!self.votes.find_by(voted_by_id: voted_by.id)
    rescue NoMethodError, Mongoid::Errors::DocumentNotFound
      false
    end

    module ClassMethods
      attr_reader :vote_range

      def set_vote_range(val)
        raise 'argument should be a Range' unless val.is_a?(Range)
        @vote_range = val
      end

      def reset_vote_range
        @vote_range = nil
      end
    end

    private
    def update_votes(mark, retract = false)
      opts = {
        '$inc' => { vote_count: retract ? -1 : 1 },
        '$set' => { vote_value: self.vote_value }
      }

      if retract
        opts['$pull'] = { votes: { _id: mark.id } }
      else
        opts['$push'] = { votes: mark.as_json }
      end

      self.collection.find(_id: self.id).update_one(opts).modified_count > 0
    end

    def update_vote_value(mark, retract = false)
      value, vote_count_diff = [mark.value, 1].map { |v| v * (retract ? -1 : 1) }
      self.vote_value = if self.vote_count == 1 && retract
                          nil
                        else
                          (self.vote_count * self.vote_value.to_f + value) / (self.vote_count + vote_count_diff)
                        end
      self.vote_count += vote_count_diff
    end

    def add_vote_mark(mark)
      mark_is_valid = false

      _assigning do
        self.votes << mark
        mark_is_valid = mark.valid?

        mark_is_valid && update_vote_value(mark)
      end

      mark_is_valid && update_votes(mark)
    end

    def remove_vote_mark(mark)
      _assigning do
        self.votes.reject! { |v| v.id == mark.id }
        update_vote_value(mark, true)
      end

      update_votes(mark, true)
    end
  end
end
