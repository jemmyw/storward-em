require 'eventmachine'
require 'evma_httpserver'
require 'em-http'
require 'em-mongo'
require 'addressable/uri'
require 'logger'
require 'ruby-debug'

dir = File.join(File.dirname(__FILE__), 'storward')

%w(property request forward forward_handler worker server config).each do |file|
  require File.join(dir, file)
end

module Storward
  def run
    EventMachine::run do
      EventMachine.epoll
      Storward::Server.run
      Storward::Worker.new.run
    end
  end
  module_function :run

  def log_error(log_type, message, error)
    logger = Storward.logger(log_type)
    logger.error message

    if error
      logger.error error.to_s
      logger.error error.backtrace.join("\n")
    end
  end
  module_function :log_error

  def logger(log_type)
    Logger.new(Storward::Server.configuration.send("#{log_type}_log") || $stdout)
  end
  module_function :logger
end
