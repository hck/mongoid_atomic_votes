$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

MODELS = File.join(File.dirname(__FILE__), 'models')

require 'simplecov'

SimpleCov.start

require 'rubygems'
require 'mongoid'
require 'mongoid_atomic_votes'
require 'database_cleaner'
require 'factory_girl'

Dir["#{MODELS}/*.rb"].each { |f| require f }

Mongoid.configure do |config|
  config.connect_to 'mongoid_atomic_votes_test'
end

#Mongoid.logger = Logger.new($stdout)
#Moped.logger = Logger.new($stdout)

#Mongoid.logger.level = Logger::DEBUG
#Moped.logger.level = Logger::DEBUG

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