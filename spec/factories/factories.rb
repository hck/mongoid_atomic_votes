FactoryGirl.define do
  factory :user do
    sequence(:login) { |n| "user_#{n}" }
  end

  factory :post do
    sequence(:title) { |n| "post_#{n}" }
  end

  factory :vote, class: 'Mongoid::AtomicVotes::Vote' do
    value { rand(0..10) }
    sequence(:voted_by_id) { |n| n }
    voter_type 'User'
  end
end
