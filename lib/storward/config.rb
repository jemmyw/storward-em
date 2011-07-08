require 'storward/property'
require 'storward/path_handler'

Dir[File.join(File.dirname(__FILE__), 'handlers', '*.rb')].each do |file|
  require file
end

module Storward
  class Config
    extend Property

    property :couch_host, :default => "localhost"
    property :couch_db,   :default => "storward"
    property :couch_port, :default => 5984
    
    property :port,       :default => 8081

    property :worker_log, :default => $stdout
    property :access_log, :default => $stdout
    property :forward_log, :default => $stdout
    property :sweeper_log, :default => $stdout

    property :worker_delay, :default => 5

    property :sweeper_delay, :default => 3600

    attr_reader :forwards

    def self.configure
      @configuration = new(&Proc.new)
    end

    def self.configuration
      @configuration
    end

    def self.method_missing(method, *args)
      if args.empty?
        configuration.send(method)
      else
        super
      end
    end

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

    def couchdb(&callback)
      EM::CouchDB::Connection.new(:host => couch_host, :port => couch_port) do |cn|
        cm = cn.get_db(couch_db, true, &callback)
        cm.errback do
          raise "Could not connect to CouchDB"
        end
      end
    end
  end
end
