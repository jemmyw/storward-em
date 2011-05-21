module Storward
  class Request
    class Saver
      include EventMachine::Deferrable

      def initialize(request, to)
        begin
          conf = Storward::Server.configuration

          cn = EM::Mongo::Connection.new(conf.mongo_host || "localhost")
          db = cn.db(conf.mongo_db || "storward")
          collection = db.collection("requests")
          doc = request.to_hash.dup
          doc[:to] = to.to_s

          EM.next_tick do
            begin
              collection.insert(doc)
              succeed
              cn.close
            rescue Exception => e
              fail(e)
            end
          end
        rescue Exception => e
          fail(e)
        end
      end
    end

    ATTRIBUTES = [:request_uri, :path_info, :method, :content, :content_type, :query]
    ATTRIBUTES.each{|a| attr_accessor a}

    attr_accessor :attempts, :sent

    def initialize(*attributes)
      ATTRIBUTES.each_with_index do |name, index|
        self.send("#{name}=", attributes[index].dup) if attributes[index]
      end
      self.attempts = 0
      self.sent = false
    end

    def method
      @method.to_s.downcase
    end

    def uri
      Addressable::URI.parse(request_uri)
    end

    def to_hash
      {}.tap do |hash|
        ATTRIBUTES.each do |a|
          hash[a] = self.send(a)
        end
        hash[:attempts] = attempts
        hash[:sent] = sent
      end
    end

    def forward(to)
      request_options = {
        :head => {'Content-Type' => content_type},
        :query => query,
        :redirects => 0
      }
      request_options[:body] = content if method =~ /post|put/
      uri = to.dup
      uri.path = path_info

      EventMachine::HttpRequest.new(uri).send(method, request_options)
    end

    def save(to)
      to = to.dup
      to.path = path_info
      Saver.new(self, to)
    end
  end
end
