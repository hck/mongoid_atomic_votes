FactoryGirl.define do
  factory :user do
    sequence(:login) {|n| "user_#{n}"}
  end

  factory :post do
    sequence(:title) {|n| "post_#{n}"}
  end
end