unless ENV['CI']
  require 'simplecov'
  SimpleCov.start do
    add_filter 'spec'
    add_filter '.bundle'
  end
end

require_relative '../lib/hash_params'
require 'minitest/spec'
require 'minitest/autorun'
require 'pry'

#require 'minitest/mock'

# require 'rack/test'
#
# require 'dummy/app'
#
# def app
#   App
# end
#
# #include Rack::Test::Methods
