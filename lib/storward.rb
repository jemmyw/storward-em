require 'eventmachine'
require 'evma_httpserver'
require 'em-http'
require 'em-mongo'
require 'addressable/uri'

dir = File.join(File.dirname(__FILE__), 'storward')

%w(property request forward forward_handler server config).each do |file|
  require File.join(dir, file)
end
