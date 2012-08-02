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

  #describe 'when has votes' do
  #  before(:each) do
  #
  #  end
  #end
end