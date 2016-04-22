require 'spec_helper'

RSpec.describe Mongoid::AtomicVotes::Vote do
  let(:vote) { FactoryGirl.build(:vote, atomic_voteable: post) }
  let(:post) { FactoryGirl.create(:post) }

  it { expect(vote).to be_valid }

  it 'is not valid without vote value' do
    vote.value = nil
    expect(vote).not_to be_valid
  end

  it 'is not valid without voted_by_id' do
    vote.voted_by_id = nil
    expect(vote).not_to be_valid
  end

  it 'is not valid without voter type' do
    vote.voter_type = nil
    expect(vote).not_to be_valid
  end

  context 'with vote range' do
    before do
      vote.atomic_voteable = post
      post.class.vote_range = 2..5
    end

    after { post.class.reset_vote_range }

    it 'is valid if value is in range specified in vote_range' do
      vote.value = rand(post.class.vote_range)
      expect(vote).to be_valid
    end

    it 'is not valid if value is out of range specified in vote_range' do
      vote.value = [1, 6].sample
      expect(vote).not_to be_valid
    end
  end
end
