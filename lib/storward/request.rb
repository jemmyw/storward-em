module Storward
  class Request
    class Saver
      include EventMachine::Deferrable

      attr_accessor :request

      def initialize(request)
        begin
          self.request = request
          
          conf = Storward::Server.configuration

          @cn = EM::Mongo::Connection.new(conf.mongo_host || "localhost")
          @db = @cn.db(conf.mongo_db || "storward")
          @collection = @db.collection("requests")
          @doc = request.to_hash.dup

          if request.new_record?
            insert
          else
            update
          end
        rescue Exception => e
          fail(e)
        end
      end

      def insert
        EM.next_tick do
          begin
            request._id = @collection.insert(@doc)
            succeed
          rescue Exception => e
            fail(e)
          ensure
            @cn.close
          end
        end
      end

      def update
        @collection.first({:_id => request._id}) do |ex_doc|
          begin
            raise "Couldn't find document with id #{request._id}" if ex_doc.nil?
            raise "Request is held by another worker" if ex_doc[:worker_id] && ex_doc[:worker_id] != request.worker_id
            @collection.save(@doc)
            succeed
          rescue Exception => e
            fail(e)
          ensure
            @cn.close
          end
        end
      end
    end

    ATTRIBUTES = [:request_uri, :path_info, :method, :content, :content_type, :query]
    ATTRIBUTES.each{|a| attr_accessor a}

    attr_accessor :_id, :attempts, :sent, :to, :proxying, :worker_id, :response_content, :response_header, :response_status

    def initialize(*attributes)
      ATTRIBUTES.each_with_index do |name, index|
        self.send("#{name}=", attributes[index].dup) if attributes[index]
      end
      self.attempts = 0
      self.sent = false
    end

    def self.next_available(&block)
      conf = Storward::Server.configuration
      cn = EM::Mongo::Connection.new(conf.mongo_host || "localhost")
      db = cn.db(conf.mongo_db||"storward")
      collection = db.collection("requests")

      collection.first({:sent => false, :proxying => false, :worker_id => nil}) do |doc|
        if doc
          yield Request.from_hash(doc)
        else
          yield nil
        end
      end
        
      cn.close
    end

    def new_record?
      self._id.nil?
    end

    def method
      @method.to_s.downcase
    end

    def uri
      Addressable::URI.parse(request_uri)
    end

    def to=(uri)
      @to = uri.dup
      @to.path = path_info
    end

    def to_hash
      {}.tap do |hash|
        hash[:_id] = _id if _id
        hash[:to] = to.to_s

        %w(attempts sent proxying worker_id response_content response_header response_status).each do |name|
          hash[name.to_sym] = self.send(name)
        end
        
        ATTRIBUTES.each do |a|
          hash[a] = self.send(a)
        end
      end
    end

    def self.from_hash(hash)
      Request.new(*ATTRIBUTES.map{|a| hash[a.to_s]}).tap do |request|
        request._id = hash['_id']
        request.attempts = hash['attempts'] || 0
        request.sent = hash['sent']
        request.to = Addressable::URI.parse(hash['to'])
        request.proxying = hash['proxying']
        request.worker_id = hash['worker_id']
      end
    end

    def forward
      puts "Sending request #{path_info}"
      self.attempts += 1

      request_options = {
        :head => {'Content-Type' => content_type},
        :query => query,
        :redirects => 0
      }
      request_options[:body] = content if method =~ /post|put/
      uri = to.dup
      uri.path = path_info

      EventMachine::HttpRequest.new(uri).send(method, request_options).tap do |http|
        http.callback do
          self.sent = true
          self.response_content = http.response
          self.response_header = http.response_header
          self.response_status = http.response_header.status
        end
        http.errback do
          begin
            self.response_content = http.response
            self.response_header = http.response_header
            self.response_status = http.response_header.status
          rescue Exception => e
          end
        end
      end
    end

    def save
      Saver.new(self)
    end
  end
end
