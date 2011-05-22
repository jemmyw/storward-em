module Storward
  class Server < EventMachine::Connection
    include EventMachine::HttpServer

    def self.run
      EventMachine::start_server("0.0.0.0", configuration.port, self)
      puts "Listening on 0.0.0.0:#{configuration.port}"
    end      

    def self.configure
      @configuration = Config.new(&Proc.new)
    end

    def self.configuration
      @configuration
    end

    def configuration
      self.class.configuration
    end

    def process_http_request
      response = EventMachine::DelegatedHttpResponse.new(self)
      request = Request.new(@http_request_uri, @http_path_info, @http_request_method, @http_content, @http_content_type, @http_query)

      forward = configuration.forwards.detect do |f|
        f.handles?(request)
      end

      if forward
        handler = forward.handle(request, response)
        handler.callback do
          response.send_response
        end
        handler.errback do |error|
          response.status = 500
          response.content = error
          response.send_response
        end
      else
        response.status = 404
        response.content = "File not found"
        response.send_response
      end
    end
  end
end
