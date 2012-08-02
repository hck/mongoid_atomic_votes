require 'spec_helper'

describe Post do
  before(:each) do
    @users = FactoryGirl.create_list(:user, 2)
    @post = FactoryGirl.create(:post)
  end

  it "has Mongoid::AtomicVotes module" do
    subject.class.ancestors.include?(Mongoid::AtomicVotes).should be_true
  end

  it { should respond_to :vote }
  it { should respond_to :retract }
  it { should respond_to :has_votes? }
  it { should respond_to :vote_count }
  it { should respond_to :vote_value }
  it { should respond_to :votes }

  it { subject.class.respond_to?(:set_vote_range).should be_true }
  it { ->{subject.class.set_vote_range(1)}.should raise_exception }

  describe '#votes' do
    it 'is array of votes' do
      @post.votes.should be_an_instance_of Array
    end
  end

  describe 'when does not have votes' do
    it 'is in not_voted scope' do
      subject.class.not_voted.include?(@post).should be_true
    end

    it 'is not in voted scope' do
      subject.class.voted.include?(@post).should be_false
    end

    it 'is not in voted_by scope' do
      @users.each do |u|
        subject.class.voted_by(u).include?(@post).should be_false
      end
    end

    it '#vote_count returns 0' do
      @post.vote_count.should == 0
    end

    it '#vote_value returns nil' do
      @post.vote_value.should be_nil
    end

    it '#votes returns empty array' do
      @post.votes.should == []
    end

    it '#has_votes? returns false' do
      @post.vote_count.should == 0
      @post.has_votes?.should be_false
    end

    it '#voted_by? returns false with any resource' do
      @users.each{|u| @post.voted_by?(u).should be_false}
    end

    it '#vote returns true on successful vote' do
      @users.each{|u| @post.vote(rand(1..10), u).should be_true}

      vote_value = @post.votes.map(&:value).sum.to_f/@post.votes.size
      
      @post.vote_value.should == vote_value
      @post.vote_count.should == @users.size
      @post.votes.size.should == @users.size

      Post.find(@post.id).vote_value.should == vote_value
      Post.find(@post.id).vote_count.should == @users.size
      Post.find(@post.id).votes.size.should == @users.size
    end
  end

  describe 'when has votes' do
    before(:each) do
      @users.each{|u| @post.vote(rand(1..10), u)}
    end

    it 'is not in the not_voted scope' do
      subject.class.not_voted.include?(@post).should be_false
    end

    it 'is in voted scope' do
      subject.class.voted.include?(@post).should be_true
    end

    it 'is in voted_by scope for each voted user' do
      @users.each{|u| subject.class.voted_by(u).include?(@post).should be_true}
    end

    it '#vote_count returns count of votes' do
      @post.vote_count.should eq(@post.votes.size)
    end

    it '#vote_value returns actual vote value' do
      vote_value = @post.votes.map(&:value).sum.to_f/@post.votes.size
      @post.vote_value.should eq(vote_value)
    end

    it '#votes returns array of vote marks' do
      @post.votes.tap do |votes|
        votes.class.should == Array
        votes.empty?.should be_false
        votes.size.should == @users.size
        votes.map(&:voted_by_id).sort.should == @users.map(&:id).sort
      end
    end

    it '#has_votes? returns true' do
      @post.vote_count.should == @post.votes.size
      @post.has_votes?.should be_true
    end

    it '#voted_by? returns true for all voted resource' do
      @users.each{|u| @post.voted_by?(u).should be_true}
    end

    it '#retract returns true on successful vote retract' do
      cnt = @users.size

      @users.each do |u|
        @post.retract(u).should be_true
        cnt -= 1

        vote_value = @post.votes.size == 0 ? 0 : @post.votes.map(&:value).sum.to_f/@post.votes.size

        @post.vote_value.should == vote_value
        @post.vote_count.should == @post.votes.size
        @post.vote_count.should == cnt

        Post.find(@post.id).vote_value.should == vote_value
        Post.find(@post.id).vote_count.should == cnt
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
      Mongoid::AtomicVotes::Vote.vote_range.should == (1..5)
    end

    it 'Vote is not valid if its value is not in specified vote_range' do
      @vote = Mongoid::AtomicVotes::Vote.new(value: rand(6..10), voted_by_id: @users.first.id, voter_type: @users.first.class.name)
      @vote.should_not be_valid
      @vote.errors.messages[:value].first.should =~ /included in the list/
    end
  end
end