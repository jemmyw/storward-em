require 'eventmachine'
require 'evma_httpserver'
require 'em-http'
require 'addressable/uri'
require 'logger'

$: << File.dirname(__FILE__)
require 'storward/config'
require 'storward/server'
require 'storward/worker'
require 'storward/sweeper'

module Storward
  def run
    EventMachine::run do
      Signal.trap("TERM") { Storward.stop }
      Signal.trap("INT") { Storward.stop }

      EventMachine.epoll

      Storward::Server.run
      Storward::Worker.run
      Storward::Sweeper.run
    end
  end
  module_function :run

  def stop
    logger("access").info("Stopping...")
    EM.stop
  end
  module_function :stop

  def log_error(log_type, message, error)
    logger = Storward.logger(log_type)
    logger.error message

    if error
      logger.error error.to_s
      logger.error error.backtrace.join("\n") if error.backtrace
    end
  end
  module_function :log_error

  def logger(log_type)
    Logger.new(Storward::Config.send("#{log_type}_log") || $stdout)
  end
  module_function :logger

  def configure
    Storward::Config.configure(&Proc.new)
  end
  module_function :configure

  def configuration
    Storward::Config.configuration
  end
  module_function :configuration
end
