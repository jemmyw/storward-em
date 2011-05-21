module Storward
  class ForwardHandler
    include EM::Deferrable

    attr_reader :forward, :request, :response

    def initialize(forward, request, response)
      @forward = forward
      @request = request
      @response = response

      @request_saved = false
      @request_updated = false
      @request_proxied = false

      @request_not_saved = false
      @request_not_updated = false
      @request_not_proxied = false

      save_request
      proxy_request if forward.proxy?
    end

    def handler_event
      if @request_saved
        if !forward.proxy? || @request_proxied
          if @request_updated
            succeed
          elsif @request_not_updated
            self.fail(["Request was sent but could not be updated in store", @request_not_updated])
          else
            request.sent = true
            save_request
          end
        elsif @request_not_proxied
          self.fail(["Request could not be proxied, but was saved", @request_not_proxied])
        end
      elsif @request_not_saved
        self.fail(["Request could not be saved", @request_not_saved])
      end
    end

    def save_request
      saver = request.save(@forward.uri)
      saver.callback do
        if @request_saved
          @request_updated = true
        else
          @request_saved = true
        end
        handler_event
      end
      saver.errback do |error|
        if @request_saved
          @request_not_updated = error
        else
          @request_not_saved = error
        end
        handler_event
      end
    end

    def rewrite(uri)
      uri = Addressable::URI.parse(uri.to_s)
      debugger
      uri.host = request.uri.host
      uri.port = request.uri.port
    end

    def proxy_request
      http = request.forward(@forward.uri)

      http.callback do
        @response.status = http.response_header.status
        @response.content_type http.response_header['CONTENT_TYPE']
        @response.headers["Location"] = rewrite(http.response_header['LOCATION']) if http.response_header['LOCATION']
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
