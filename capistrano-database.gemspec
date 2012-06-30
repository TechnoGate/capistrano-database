# -*- encoding: utf-8 -*-
require File.expand_path('../lib/capistrano-database/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Wael M. Nasreddine"]
  gem.email         = ["wael.nasreddine@gmail.com"]
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "capistrano-database"
  gem.require_paths = ["lib"]
  gem.version       = Capistrano::Database::VERSION
end
