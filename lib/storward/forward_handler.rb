module Storward
  class ForwardHandler
    include EM::Deferrable

    attr_reader :forward, :request, :response

    def initialize(forward, request, response)
      @forward = forward
      @request = request
      @response = response

      @request_saved = false
      @request_proxied = false

      @request_not_saved = false
      @request_not_proxied = false

      @request.to = @forward.uri
      @request.proxying = forward.proxy?

      save_request
      proxy_request if forward.proxy?
    end

    def handler_event
      if @request_saved
        if !forward.proxy? || @request_proxied
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
