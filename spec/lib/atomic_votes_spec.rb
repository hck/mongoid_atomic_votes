require 'spec_helper'

describe Post do
  let!(:users) { FactoryGirl.create_list(:user, 2) }
  let!(:post) { FactoryGirl.create(:post) }

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
    it { expect(post.votes).to be_an_instance_of(Array) }
  end

  describe 'when does not have votes' do
    it 'is in not_voted scope' do
      expect(subject.class.not_voted).to include(post)
    end

    it 'is not in voted scope' do
      expect(subject.class.voted).not_to include(post)
    end

    it 'is not in voted_by scope' do
      expect(users.all? { |user| subject.class.voted_by(user).include?(post) == false }).to eq(true)
    end

    it '#vote_count returns 0' do
      expect(post.vote_count).to eq(0)
    end

    it '#vote_value returns nil' do
      expect(post.vote_value).to be_nil
    end

    it '#votes returns empty array' do
      expect(post.votes).to eq([])
    end

    it '#has_votes? returns false' do
      expect(post.has_votes?).to eq(false)
    end

    it '#voted_by? returns false for any voter' do
      expect(users.all? { |user| post.voted_by?(user) == false }).to eq(true)
    end

    describe '#vote' do
      let(:votes) { [rand(1..10), rand(1..10)] }
      let(:expected_vote_value) { votes.sum.to_f / users.size }

      it 'returns true on successfull vote' do
        expect(users.all? { |user| post.vote(rand(1..10), user) == true }).to eq(true)
      end

      it 'properly calculates vote value' do
        users.each_with_index { |user, index| post.vote(votes[index], user) }
        expect(post.vote_value).to eq(expected_vote_value)
      end

      it 'properly adds vote' do
        expect { post.vote(rand(1..10), users.sample) }.to change { post.vote_count }.by(1)
      end

      it 'persists changes to database' do
        users.each_with_index { |user, index| post.vote(votes[index], user) }

        db_post = Post.find(post.id)
        votes_info = [
          db_post.vote_value,
          db_post.vote_count,
          db_post.votes.size
        ]
        expect(votes_info).to eq([expected_vote_value, users.size, users.size])
      end
    end
  end

  describe 'when has votes' do
    before(:each) do
      users.each { |user| post.vote(rand(1..10), user) }
    end

    it 'is not in the not_voted scope' do
      expect(subject.class.not_voted).not_to include(post)
    end

    it 'is in voted scope' do
      expect(subject.class.voted).to include(post)
    end

    it 'is in voted_by scope for each voted user' do
      expect(users.all? { |user| subject.class.voted_by(user).include?(post) == true }).to eq(true)
    end

    it '#vote_count returns count of votes' do
      expect(post.vote_count).to eq(post.votes.size)
    end

    it '#vote_value returns actual vote value' do
      expected_vote_value = post.votes.map(&:value).sum.to_f / post.votes.size
      expect(post.vote_value).to eq(expected_vote_value)
    end

    describe '#votes' do
      let(:votes) { post.votes }

      it { expect(votes.class).to eq(Array) }
      it { expect(votes).not_to be_empty }
      it { expect(votes.size).to eq(users.size) }
      it { expect(votes.map(&:voted_by_id)).to match_array(users.map(&:id)) }
    end

    it '#has_votes? returns true' do
      expect(post.has_votes?).to eq(true)
    end

    it '#voted_by? returns true for all voted resource' do
      expect(users.all? { |user| post.voted_by?(user) == true }).to eq(true)
    end

    describe '#retract' do
      it 'returns true on successfull vote retract' do
        expect(users.all? { |user| post.retract(user) == true }).to eq(true)
      end

      it 'properly calculates vote value' do
        user = users.sample
        retracted_vote_value = post.votes.find_by(voted_by_id: user.id).value
        expected_vote_value = (post.votes.map(&:value).sum.to_f - retracted_vote_value) / (users.size - 1)

        post.retract(user)
        expect(post.vote_value).to eq(expected_vote_value)
      end

      it 'properly decreases vote count' do
        expect { post.retract(users.sample) }.to change { post.vote_count }.by(-1)
      end

      it 'persists changes to database' do
        user = users.sample
        retracted_vote_value = post.votes.find_by(voted_by_id: user.id).value
        expected_vote_value = (post.votes.map(&:value).sum.to_f - retracted_vote_value) / (users.size - 1)

        post.retract(user)

        db_post = Post.find(post.id)
        votes_info = [
            db_post.vote_value,
            db_post.vote_count,
            db_post.votes.size
        ]
        expect(votes_info).to eq([expected_vote_value, users.size - 1, users.size - 1])
      end
    end
  end

  describe 'when model has vote_range' do
    before { Post.set_vote_range(1..5) }

    it 'marks vote as invalid if value is out of range' do
      post.vote(rand(6..10), users.sample)
      expect(post.votes.last).not_to be_valid
    end

    it 'marks post as invalid' do
      post.vote(rand(6..10), users.sample)
      expect(post).not_to be_valid
    end

    it 'has properly filled error messages for invalid vote' do
      post.vote(rand(6..10), users.sample)
      expect(post.votes.last.errors.messages[:value].first).to match(/included in the list/)
    end

    describe '#reset_vote_range' do
      let(:klass) { post.class }

      it 'sets vote_range to nil' do
        expect { klass.reset_vote_range }.to change { klass.vote_range }.to(nil)
      end
    end
  end
end
