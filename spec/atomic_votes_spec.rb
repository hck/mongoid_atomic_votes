require 'pry'
require 'spec_helper'

describe Post do
  before(:each) do
    @users = FactoryGirl.create_list(:user, 2)
    @post = FactoryGirl.create(:post)
  end

  it 'has Mongoid::AtomicVotes module' do
    expect(subject.class.ancestors).to include(Mongoid::AtomicVotes)
  end

  it { expect(subject).to respond_to(:vote) }
  it { expect(subject).to respond_to(:retract) }
  it { expect(subject).to respond_to(:has_votes?) }
  it { expect(subject).to respond_to(:vote_count) }
  it { expect(subject).to respond_to(:vote_value) }
  it { expect(subject).to respond_to(:votes) }

  it { expect(subject.class).to respond_to(:set_vote_range) }
  it { expect { subject.class.set_vote_range(1) }.to raise_error('argument should be a Range') }

  describe '#votes' do
    it 'is array of votes' do
      expect(@post.votes).to be_an_instance_of(Array)
    end
  end

  describe 'when does not have votes' do
    it 'is in not_voted scope' do
      expect(subject.class.not_voted).to include(@post)
    end

    it 'is not in voted scope' do
      expect(subject.class.voted).not_to include(@post)
    end

    it 'is not in voted_by scope' do
      @users.each do |u|
        expect(subject.class.voted_by(u)).not_to include(@post)
      end
    end

    it '#vote_count returns 0' do
      expect(@post.vote_count).to eq(0)
    end

    it '#vote_value returns nil' do
      expect(@post.vote_value).to be_nil
    end

    it '#votes returns empty array' do
      expect(@post.votes).to eq([])
    end

    it '#has_votes? returns false' do
      expect(@post.vote_count).to eq(0)
      expect(@post.has_votes?).to be_falsey
    end

    it '#voted_by? returns false with any resource' do
      @users.each do |u|
        expect(@post.voted_by?(u)).to be_falsey
      end
    end

    it '#vote returns true on successful vote' do
      @users.each do |u|
        expect(@post.vote(rand(1..10), u)).to be_truthy
      end

      vote_value = @post.votes.map(&:value).sum.to_f/@post.votes.size

      expect(@post.vote_value).to eq(vote_value)
      expect(@post.vote_count).to eq(@users.size)
      expect(@post.votes.size).to eq(@users.size)

      Post.find(@post.id).tap do |post|
        expect(post.vote_value).to eq(vote_value)
        expect(post.vote_count).to eq(@users.size)
        expect(post.votes.size).to eq(@users.size)
      end
    end
  end

  describe 'when has votes' do
    before(:each) do
      @users.each{|u| @post.vote(rand(1..10), u)}
    end

    it 'is not in the not_voted scope' do
      expect(subject.class.not_voted).not_to include(@post)
    end

    it 'is in voted scope' do
      expect(subject.class.voted).to include(@post)
    end

    it 'is in voted_by scope for each voted user' do
      @users.each do |u|
        expect(subject.class.voted_by(u)).to include(@post)
      end
    end

    it '#vote_count returns count of votes' do
      expect(@post.vote_count).to eq(@post.votes.size)
    end

    it '#vote_value returns actual vote value' do
      vote_value = @post.votes.map(&:value).sum.to_f/@post.votes.size
      expect(@post.vote_value).to eq(vote_value)
    end

    it '#votes returns array of vote marks' do
      @post.votes.tap do |votes|
        expect(votes.class).to eq(Array)
        expect(votes).not_to be_empty
        expect(votes.size).to eq(@users.size)
        expect(votes.map(&:voted_by_id).sort).to eq(@users.map(&:id).sort)
      end
    end

    it '#has_votes? returns true' do
      expect(@post.vote_count).to eq(@post.votes.size)
      expect(@post.has_votes?).to be_truthy
    end

    it '#voted_by? returns true for all voted resource' do
      @users.each do |u|
        expect(@post.voted_by?(u)).to be_truthy
      end
    end

    it '#retract returns true on successful vote retract' do
      cnt = @users.size

      @users.each do |u|
        expect(@post.retract(u)).to be_truthy
        cnt -= 1

        vote_value = @post.votes.size == 0 ? nil : @post.votes.map(&:value).sum.to_f/@post.votes.size

        expect(@post.vote_value).to eq(vote_value)
        expect(@post.vote_count).to eq(@post.votes.size)
        expect(@post.vote_count).to eq(cnt)

        expect(Post.find(@post.id).vote_value).to eq(vote_value)
        expect(Post.find(@post.id).vote_count).to eq(cnt)
        Post.find(@post.id).votes.size == cnt
      end
    end
  end

  describe 'when model has vote_range' do
    before(:each) do
      Post.send(:set_vote_range, 1..5)
      @post = FactoryGirl.create(:post)
    end

    it 'Vote has vote_range set up' do
      expect(Mongoid::AtomicVotes::Vote.vote_range).to eq((1..5))
    end

    it 'Vote is not valid if its value is not in specified vote_range' do
      @vote = Mongoid::AtomicVotes::Vote.new(value: rand(6..10), voted_by_id: @users.first.id, voter_type: @users.first.class.name)
      expect(@vote).not_to be_valid
      expect(@vote.errors.messages[:value].first).to match(/included in the list/)
    end
  end
end
