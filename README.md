# MongoidAtomicVotes

mongoid_atomic_votes adds possibility to vote on mongoid documents.
Each vote mark goes to db by one atomic query that increments vote count, sets vote_value (overall document vote score) and pulls vote mark (embedded document with additional info about voter) to db.

## Installation

Add this line to your application's Gemfile:

    gem 'mongoid_atomic_votes'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install mongoid_atomic_votes

## Usage

Include Mongoid::AtomicVotes into your mongoid documents for which you wish to add vote possibility:

    class Article
      include Mongoid::Document
      include Mongoid::AtomicVotes
    end

and then just call methods on model instances to vote/retract:

    @article = Article.find(...)
    @user = User.find(...)
    @article.vote(1, @user) #vote
    @article.retract(@user) #retract

You dont need to save your document after you called `#vote` or `#retract`

Getting overall document vote score:

    @article.vote_value

Getting overall vote count:

    @article.vote_count

Check whether document has votes:

    @article.has_votes?

Check whether document was voted by some voters:

    @article.voted_by? @user

## Scopes

There are some useful scopes:

    Article.voted               # documents that have votes
    Article.not_voted           # documents without votes
    Article.voted_by(@voter)    # documents, voted by @voter
    Article.vote_value_in(3..5) # documents with vote_value in 3..5
    Article.highest_voted(5)    # 5 highest voted documents
