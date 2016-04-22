class Post
  include Mongoid::Document
  include Mongoid::AtomicVotes

  field :title
end
