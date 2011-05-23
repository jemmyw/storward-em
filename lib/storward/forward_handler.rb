module Storward
  class ForwardHandler
    include EM::Deferrable
    extend Property

    attr_reader :request, :response

    property :to, :proxy

    def initialize(matches, request, response)
      @request = request
      @response = response

      instance_exec *matches, &Proc.new

      @request_saved = false
      @request_proxied = false

      @request_not_saved = false
      @request_not_proxied = false

      @request.to = Addressable::URI.parse(self.to)
      @request.proxying = proxy?

      save_request
      proxy_request if proxy?
    end

    def handler_event
      if @request_saved
        if !proxy?
          @response.status = 200
          self.succeed
        elsif @request_proxied
          request.proxying = false
          request.save.tap do |saver|
            saver.callback { self.succeed }
            saver.errback  {|error| self.fail(["Request was sent but could not be updated in store. Manual intervention required", error])}
          end
        elsif @request_not_proxied
          request.proxying = false
          request.save.tap do |saver|
            saver.callback { self.fail(["Request could not be proxied but was saved", @request_not_proxied]) }
            saver.errback  {|error| self.fail(["Request could not be proxied, was saved but not updated, needs manual intervention", error])}
          end
        end
      elsif @request_not_saved
        self.fail(["Request could not be saved", @request_not_saved])
      end
    end

    def save_request
      saver = request.save
      saver.callback do
        @request_saved = true
        handler_event
      end
      saver.errback do |error|
        @request_not_saved = error
        handler_event
      end
    end

    def proxy_request
      http = request.forward

      http.callback do
        @response.status = http.response_header.status
        @response.content_type http.response_header['CONTENT_TYPE']
        @response.headers["Location"] = http.response_header['LOCATION'] if http.response_header['LOCATION']
        @response.content = http.response
        @request_proxied = true
        handler_event
      end
      http.errback do
        @request_not_proxied = true
        handler_event
      end
    end
  end
end
