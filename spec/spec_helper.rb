MODELS = File.join(File.dirname(__FILE__), 'models')

require 'rubygems'
require 'database_cleaner'
require 'factory_girl'
require 'simplecov'

SimpleCov.start do
  add_filter '/.gems/'
  add_filter '/.bundle/'
end

require 'mongoid'
require 'mongoid_atomic_votes'

Dir["#{MODELS}/*.rb"].each { |f| require f }

Mongoid.configure do |config|
  config.connect_to 'mongoid_atomic_votes_test'
end

Mongoid.logger.level = Logger::ERROR
Mongo::Logger.logger.level = Logger::ERROR

FactoryGirl.definition_file_paths = [File.join(File.dirname(__FILE__), 'factories')]
FactoryGirl.find_definitions

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.orm = 'mongoid'
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
