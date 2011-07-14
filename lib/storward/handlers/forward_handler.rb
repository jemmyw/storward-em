require 'storward/handler'

module Storward
  # Forward handler for forwarding requests
  #
  # to => the full URL to forward the request to
  # proxy => if true then the request will be forwarded and the response returned. 
  #   Otherwise the request will be saved and forwarded in the background
  # fallback_response => The response to send when not proxying or when an error is handled
  # error_statuses => Array of HTTP status errors to consider network errors
  class ForwardHandler < Handler
    property :to, :proxy, :fallback_response
    property :timeout, :default => 30
    property :error_statuses, :default => []

    def handle_request
      @request_saved = false
      @request_proxied = false

      @request_not_saved = false
      @request_not_proxied = false

      @request.to = Addressable::URI.parse(self.to)
      @request.timeout = timeout
      @request.proxying = proxy?

      save_request
      proxy_request if proxy?
    end

    def handler_event
      if @request_saved
        if !proxy?
          fallback_response ||= {:status => 200}
          fallback
        elsif @request_proxied
          request.proxying = false
          request.save.tap do |saver|
            saver.callback { self.succeed }
            saver.errback  {|error| self.fail(["Request was sent but could not be updated in store. Manual intervention required", error])}
          end
        elsif @request_not_proxied
          request.proxying = false
          request.save.tap do |saver|
            saver.callback do
              if fallback?
                fallback
              else
                self.fail(["Request could not be proxied but was saved", @request_not_proxied])
              end
            end
            saver.errback do |error| 
              self.fail(["Request could not be proxied, was saved but not updated, needs manual intervention", error])
            end
          end
        end
      elsif @request_not_saved
        self.fail(["Request could not be saved", @request_not_saved])
      end
    end

    # Is there a fallback
    def fallback?
      fallback_response
    end

    # Fill in the response from the fallback and succeed
    def fallback
      @response.status = fallback_response[:status] || 200
      @response.content_type fallback_response[:content_type] || 'text/html'
      @response.content = fallback_response[:body] || fallback_response[:content] || ""
      self.succeed
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
      request.error_statuses = self.error_statuses if self.error_statuses
      request_http = request.forward

      request_http.callback do |http|
        @response.status = http.response_header.status
        @response.content_type http.response_header['CONTENT_TYPE']
        @response.headers["Location"] = http.response_header['LOCATION'] if http.response_header['LOCATION']
        @response.content = http.response
        @request_proxied = true
        handler_event
      end
      request_http.errback do |http|
        @request_not_proxied = true
        handler_event
      end
    end
  end
end
