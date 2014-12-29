# -*- encoding: utf-8 -*-
require File.expand_path('../lib/hash_params', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'hash_params'
  s.license     = 'MIT'
  s.authors     = ['Tim Uckun']
  s.email       = 'tim@uckun.com'
  s.homepage    = 'https://github.com/timuckun/hash_params'
  s.version     = HashParams::VERSION
  s.platform    = Gem::Platform::RUBY
  s.summary     = 'Parameter Validation & Type Coercion for parameters passed in as a Hash..'
  s.description = 'hash-param allows you to declare, validate, and transform endpoint parameters as you would in frameworks like ActiveModel or DataMapper without the overhead.
                  This gem is a variation of the sinatra-param gem https://github.com/mattt/sinatra-param modified to be more generic and with some additional features'

  s.files         = Dir["./**/*"].reject { |file| file =~ /\.\/(bin|log|pkg|script|spec|test|vendor)/ }
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # gem.require_paths = ['lib']
  # gem.files         = %w(.yardopts CHANGELOG.md CONTRIBUTING.md LICENSE README.md UPGRADING.md Rakefile hashie.gemspec)
  # gem.files         += Dir['lib/**/*.rb']
  # gem.files         += Dir['spec/**/*.rb']
  # gem.test_files    = Dir['spec/**/*.rb']


  s.add_development_dependency 'rake'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'minitest-spec'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'pry'



end
