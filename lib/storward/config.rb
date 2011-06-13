require 'storward/property'
require 'storward/path_handler'

Dir[File.join(File.dirname(__FILE__), 'handlers', '*.rb')].each do |file|
  require file
end

module Storward
  class Config
    extend Property

    property :mongo_host, :default => "localhost"
    property :mongo_db,   :default => "storward"
    property :port,       :default => 8081

    property :worker_log, :default => $stdout
    property :access_log, :default => $stdout

    attr_reader :forwards

    def initialize
      @forwards = []
      instance_eval &Proc.new
    end

    def forward(path, options = {})
      handle(path, options.merge(:handler => ForwardHandler), &Proc.new)
    end

    def handle(path, options = {})
      if block_given?
        @forwards << PathHandler.new(path, options.delete(:handler), options, &Proc.new)
      else
        @forwards << PathHandler.new(path, options.delete(:handler), options){ }
      end
    end
  end
end
