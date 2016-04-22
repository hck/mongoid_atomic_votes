module Mongoid
  module AtomicVotes
    class << self
      def included(base)
        define_fields(base)
        define_relations(base)
        define_scopes(base)

        base.extend ClassMethods
      end

      private

      def define_fields(base)
        base.field :vote_count, type: Integer, default: 0
        base.field :vote_value, type: Float, default: nil
      end

      def define_relations(base)
        base.embeds_many :votes, class_name: 'Mongoid::AtomicVotes::Vote', as: :atomic_voteable
      end

      def define_scopes(base)
        scopes(base).each { |name, block| base.scope name, block }
      end

      def scopes(base)
        {
          not_voted: -> { base.where(:vote_value.exists => false) },
          voted: -> { base.where(:vote_value.exists => true) },
          voted_by: ->(resource) {
            base.where(
              'votes.voted_by_id' => resource.id,
              'votes.voter_type' => resource.class.name
            )
          },
          vote_value_in: ->(range) {
            base.where(
              :vote_value.gte => range.begin,
              :vote_value.lte => range.end
            )
          },
          highest_voted: ->(limit=10) { base.order_by(:vote_value.desc).limit(limit) }
        }
      end
    end

    # Creates an embedded vote record and updates number of votes and vote value.
    #
    # @param [Int,Float] value vote value
    # @param [Mongoid::Document] voted_by object from which the vote is done
    # @return [Boolean] success flag
    def vote(value, voted_by)
      mark = Vote.new(value: value, voted_by_id: voted_by.id, voter_type: voted_by.class.name)
      add_vote_mark(mark)
    end

    # Removes previously added vote.
    #
    # @param [Mongoid::Document] voted_by object from which the vote was done
    # @return [Boolean] success flag
    def retract(voted_by)
      mark = self.votes.find_by(voted_by_id: voted_by.id)
      mark && remove_vote_mark(mark)
    end

    # Indicates whether the document has votes or not.
    #
    # @return [Boolean]
    def has_votes?
      self.vote_count > 0
    end

    # Indicates whether the document has a vote from particular voter object.
    #
    # @param [Mongoid::Document] voted_by object from which the vote was done
    # @return [Boolean]
    def voted_by?(voted_by)
      !!self.votes.find_by(voted_by_id: voted_by.id)
    rescue NoMethodError, Mongoid::Errors::DocumentNotFound
      false
    end

    module ClassMethods
      attr_reader :vote_range

      # Specifies possible vote range which is used vote mark validation later.
      #
      # @param [Range] val new vote range, for example: 1..5
      # @return [Range] vote range, previously passed to a method as a parameter
      def vote_range=(val)
        raise ArgumentError, 'argument should be a Range' unless val.is_a?(Range)
        @vote_range = val
      end

      # Sets vote range to nil
      #
      # @return [NilClass] nil
      def reset_vote_range
        @vote_range = nil
      end
    end

    private

    def update_vote_counters(mark, increment_count_by)
      self.vote_value = calculate_vote_value(mark.value, increment_count_by)
      self.vote_count += increment_count_by
    end

    def calculate_vote_value(value, count)
      current_vote_count = self.vote_count
      new_vote_count = current_vote_count + count

      if new_vote_count > 0
        (current_vote_count * self.vote_value.to_f + value * count) / new_vote_count
      else
        nil
      end
    end

    def update_votes(query_opts)
      self.collection.find(_id: self.id).update_one(query_opts).modified_count > 0
    end

    def vote_options(mark)
      {
        '$inc' => { vote_count: 1 },
        '$set' => { vote_value: self.vote_value },
        '$push' => { votes: mark.as_json }
      }
    end

    def retract_options(mark)
      {
        '$inc' => { vote_count: -1 },
        '$set' => { vote_value: self.vote_value },
        '$pull' => { votes: { _id: mark.id } }
      }
    end

    def add_vote_mark(mark)
      mark_is_valid = false

      _assigning do
        self.votes << mark
        mark_is_valid = mark.valid?
        mark_is_valid && update_vote_counters(mark, 1)
      end

      mark_is_valid && update_votes(vote_options(mark))
    end

    def remove_vote_mark(mark)
      _assigning do
        self.votes.reject! { |vote| vote.id == mark.id }
        update_vote_counters(mark, -1)
      end

      update_votes(retract_options(mark))
    end
  end
end
