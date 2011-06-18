require 'storward/handler'

module Storward
  class ForwardHandler < Handler
    property :to, :proxy, :fallback_response

    def handle_request
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
          if fallback_response
            @response.status = fallback_response[:status] || 200
            @response.content_type fallback_response[:content_type] || 'text/html'
            @response.content = fallback_response[:body] || fallback_response[:content]
          else
            @response.status = 200
          end

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
