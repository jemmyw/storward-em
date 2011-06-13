require 'storward/handler'

module Storward
  class BasicAuthHandler < Handler
    property :username, :password, :realm
    attr_accessor :authorized

    def handler(value)
      @handler = value
      @handler_config = Proc.new if block_given?
    end

    def authorized?
      authorized
    end

    def handle_request
      if auth = request.header("Authorization")
        if auth =~ /Basic (.*)$/
          up = $1.unpack('m*').first.split(':')

          if up.length == 2 &&
            up[0] == username &&
            up[1] == password

            self.authorized = true
          end
        end
      end

      if authorized?
        handle_success
      else
        handle_failure
      end
    end

    def handle_success
      handler = if @handler_config
        @handler.new(@matches, request, response, &@handler_config)
      else
        @handler.new(@matches, request, response){}
      end

      handler.callback { self.succeed }
      handler.errback  { self.fail }
    end

    def handle_failure
      @response.status = 401
      @response.headers['WWW-Authenticate'] = "Basic realm=#{realm}"
      succeed
    end
  end
end
