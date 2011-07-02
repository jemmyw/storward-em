require 'storward/server'
require 'storward/request_saver'

module Storward
  class Request
    ATTRIBUTES = [:request_uri, :path_info, :method, :headers, :content_type, :query, :received_at]
    ATTRIBUTES.each{|a| attr_accessor a}

    attr_accessor :_id, :attempts, :sent, :to, :proxying, :worker_id, :response_content, :response_header, :response_status
    attr_accessor :content
    attr_accessor :error_statuses

    def initialize(attributes = {})
      attributes.each do |key, value|
        raise "Unknown request attribute #{key}" unless ATTRIBUTES.include?(key.to_sym)
        self.send("#{key}=", value.dup) if value
      end

      self.attempts = 0
      self.sent = false
      self.error_statuses = []
    end

    def self.next_available(&callback)
      conf = Storward::Server.configuration
      conf.couchdb do |db|
        cm = db.execute_view("requests", "next_available", :limit => 1, :map_docs => true)
        cm.callback do |docs|
          doc = docs["rows"].first
          if doc
            request = Request.from_hash(doc)
            if attachment = doc.attachments['content']
              acm = attachment.read do |content|
                request.content = content

                if attachment = doc.attachments['response_content']
                  acm2 = attachment.read do |content|
                    request.response_content = content
                    yield request
                  end
                  acm2.errback { yield request }
                else
                  yield request
                end
              end
              acm.errback { raise "Could not read attachment for #{doc.id}" }
            else
              yield request
            end
          else
            yield nil
          end
        end
        cm.errback { yield nil }
      end
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
      @to = uri
    end

    def params
      @params ||= if query
                    query.split('&').inject({}) do |m,n|
                      pm = n.split('=')
                      if pm.size == 2
                        m[pm[0]] = pm[1]
                      end
                      m
                    end
                  else
                    {}
                  end
    end

    def header(name)
      @parsed_headers ||= headers.split(/\n|\r|#{"\x00"}/).inject({}) do |m,n|
        if n =~ /^(.*?):\s*(.*)$/
          m[$1] = $2
        end
        m
      end
      @parsed_headers[name]
    end

    def to_hash
      {}.tap do |hash|
        hash[:_id] = _id if _id
        hash[:to] = to.to_s

        %w(attempts sent proxying worker_id response_header response_status received_at error_statuses).each do |name|
          hash[name.to_sym] = self.send(name)
        end

        ATTRIBUTES.each do |a|
          hash[a] = self.send(a)
        end
      end
    end

    def self.from_hash(hash)
      Request.new.tap do |request|
        ATTRIBUTES.each do |attribute|
          request.send("#{attribute}=", hash[attribute.to_s])
        end

        request._id = hash['_id']
        request.attempts = hash['attempts'] || 0
        request.sent = hash['sent']
        request.to = Addressable::URI.parse(hash['to'])
        request.proxying = hash['proxying']
        request.worker_id = hash['worker_id']
        request.received_at = hash['received_at']
        request.error_statuses = hash['error_statuses']
      end
    end

    def response_content_type
      if response_header
        response_header['CONTENT_TYPE']
      end
    end

    def forward
      self.attempts += 1

      request_options = {
        :head => {'Content-Type' => content_type},
        :query => query,
        :redirects => 0
      }
      request_options[:body] = content if method =~ /post|put/
              
      Storward.logger("forward").info "Forwarding #{method} to #{to}#{path_info} with body of length #{content.length}"

      df = DefaultDeferrable.new
      
      http = EventMachine::HttpRequest.new(self.to).send(method, request_options)
      http.callback do
        self.response_content = http.response
        self.response_header = http.response_header
        self.response_status = http.response_header.status

        if error_statuses.map(&:to_s).include?(http.response_header.status.to_s)
          Storward.logger("forward").info(%Q{Unsuccessful forward #{method} to #{to}#{path_info} #{query} Status: #{http.response_header.status}})
          df.fail http
        else
          Storward.logger("forward").info(%Q{Successful forward #{method} to #{to}#{path_info} #{query} Status: #{http.response_header.status}})
          self.sent = true
          df.succeed http
        end
      end
      http.errback do
        Storward.logger("forward").error(%Q{Unsuccessful forward #{method} to #{to}#{path_info}})

        begin
          self.response_content = http.response
          self.response_header = http.response_header
          self.response_status = http.response_header.status
        rescue Exception => e
        ensure
          df.fail http
        end
      end

      df
    end

    def save(options = {})
      RequestSaver.new(self, options)
    end
  end
end
