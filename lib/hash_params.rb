require 'yaml'
require 'erb'
require 'socket'


require_relative 'hash_params/hash_validator'
require_relative 'hash_params/validator'
require_relative 'hash_params/binding_validator'
module HashParams
  ENVIRONMENT =  ENV['HASH_PARAMS_ENV'] || (defined?(Rails) && Rails.env) || ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
  VERSION = '2.0.0'
  extend HashParams::Validator
end

require_relative 'hash_params/yaml_params'
require 'pry' if HashParams::ENVIRONMENT == 'development'





