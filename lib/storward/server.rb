require 'storward/config'
require 'storward/request'

module Storward
  class Server < EventMachine::Connection
    include EventMachine::HttpServer

    def self.run
      EventMachine::start_server("0.0.0.0", configuration.port, self)
      Storward.logger("access").info "Listening on 0.0.0.0:#{configuration.port}"

      configuration.forwards.each do |handler|
        Storward.logger("access").debug "Handler at #{handler.path}"
      end
    end      

    def self.configuration
      Storward::Config.configuration
    end

    def configuration
      self.class.configuration
    end

    def process_http_request
      begin
        response = EventMachine::DelegatedHttpResponse.new(self)

        begin
          request = Request.new(
            :request_uri => @http_request_uri,
            :path_info => @http_path_info,
            :method => @http_request_method,
            :headers => @http_headers,
            :content_type => @http_content_type,
            :query => @http_query_string,
            :received_at => Time.now,
          )
          request.content = @http_post_content

          forward = configuration.forwards.detect do |f|
            f.handles?(request)
          end

          if forward
            handler = forward.handle(request, response)
            handler.callback do
              response.send_response
              Storward.logger("access").info "#{request.method} to #{request.path_info} handled successfully. Status code: #{response.status}"
            end
            handler.errback do |error|
              response.status = 500
              response.content = error
              response.send_response

              Storward.logger("access").info "#{request.method} to #{request.path_info} handled unsuccessfully. Status code: 500. Error: #{error.to_s}"
            end
          else
            response.status = 404
            response.content = "File not found"
            response.send_response

            Storward.logger("access").info "#{request.method} to #{request.path_info} unknown. Status code: 404"
          end
        rescue Exception => request_error
          response.status= 500
          response.content = "An error occurred"
          response.send_response
          raise request_error
        end
      rescue Exception => response_error
        Storward.logger("access").error(<<-ERR)
Error processing request #{response_error.to_s}
\tmethod: #{@http_request_method}
\turi: #{@http_request_uri}
\tpath: #{@http_path_info}
\tquery: #{@http_query_string}
\n
#{response_error.backtrace.join("\n")}
ERR
      end
    end
  end
end
