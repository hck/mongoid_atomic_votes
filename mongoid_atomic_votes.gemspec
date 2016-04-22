# -*- encoding: utf-8 -*-
require File.expand_path('../lib/mongoid_atomic_votes/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ['Hck']
  gem.description   = 'Atomic votes for mongoid models'
  gem.summary       = 'Atomic votes implementation for mongoid'
  gem.homepage      = 'http://github.com/hck/mongoid_atomic_votes'

  gem.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  gem.executables   = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = 'mongoid_atomic_votes'
  gem.require_paths = ['lib']
  gem.version       = Mongoid::AtomicVotes::VERSION

  gem.add_runtime_dependency 'mongoid', ['~> 5.0']
end
