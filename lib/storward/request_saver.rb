require 'em-couchdb'

module Storward
  class RequestSaver
    include EventMachine::Deferrable

    attr_accessor :request
    attr_accessor :started_at
    attr_accessor :options

    def initialize(request, options = {})
      begin
        self.options = options
        self.started_at = Time.now
        self.request = request

        conf = Storward::Server.configuration

        EM::CouchDB::Connection.new(:host => conf.couch_host, :port => conf.couch_port) do |cn|
          cmdb = cn.get_db(conf.couch_db || "storward", true) do |db|
            if request.new_record?
              insert(db)
            else
              update(db)
            end
          end
          cmdb.errback { fail(Exception.new("Could not find or create couchdb database")) }
        end
      rescue Exception => e
        raise e
      end
    end

    def insert(db)
      document = db.new(request.to_hash)
      save(document)
    end

    def insert_attachments(document)
      if request.content && !document.attachments['content']
        document.attachments.build('content', request.content_type, request.content)
      end

      if request.response_content && !document.attachments['response_content']
        document.attachments.build('response_content', request.response_content_type, request.response_content)
      end
    end

    def update(db)
      cm = db.get(request._id) do |doc|
        fail("Couldn't find document with id #{request._id}") and return if doc.nil?

        if options[:lock]
          request.worker_id = options[:lock]
        end

        fail("Request is held by another worker") and return if doc["worker_id"] && doc["worker_id"] != request.worker_id

        if options[:unlock]
          request.worker_id = nil
        end

        request.to_hash.each do |key, value|
          doc.doc[key.to_s] = value
        end

        save(doc)
      end
      cm.errback { fail "Couldn't find document with id #{request._id}" }
    end

    def save(document)
      insert_attachments(document)

      cm = document.save
      cm.callback do
        request._id = document.id
        succeed
      end
      cm.errback do |*error|
        puts "error saving document: #{error.inspect}"
        fail(Exception.new("Could not save document"))
      end
    end
  end
end
