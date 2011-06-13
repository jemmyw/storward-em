require 'storward/property'

module Storward
  class Handler
    include EM::Deferrable
    extend Property

    attr_reader :request, :response

    def initialize(matches, request, response)
      @request = request
      @response = response

      instance_exec *matches, &Proc.new

      handle_request
    end
  end
end
