require 'storward/property'

module Storward
  class Handler
    include EM::Deferrable
    extend Property

    attr_reader :request, :response

    def initialize(matches, request, response)
      @matches = matches
      @request = request
      @response = response
      @config = Proc.new

      instance_exec *matches, &Proc.new

      handle_request
    end
  end
end
