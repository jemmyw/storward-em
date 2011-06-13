module Storward
  class MongoConnection
    attr_reader :started_at

    def initialize
      conf = Storward::Server.configuration
      @started_at = Time.now
      @cn = EM::Mongo::Connection.new(conf.mongo_host || "localhost")
      check_connection do
        begin
          @db = @cn.db(conf.mongo_db || "storward")
          yield @db
        ensure
          @cn.close
        end
      end
    end

    def check_connection(&blk)
      if @cn.connected?
        yield
      else
        if Time.now - started_at > 2
          raise "Could not connect to MongoDB"
        else
          EM.next_tick { check_connection(&blk) }
        end
      end
    end
  end
end
