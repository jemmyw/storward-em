module Storward  
  class Forward
    extend Property

    attr_accessor :paths

    property :method, :splat => true
    property :to, :proxy, :forward_on_error

    def initialize(*paths)
      self.paths = paths.flatten
      instance_eval &Proc.new
    end

    def handles?(request)
      path_match?(request.path_info) && method_match?(request.method)
    end

    def path_match?(path_info)
      paths.any? do |path|
        path_info =~ path
      end
    end

    def method_match?(request_method)
      method.map(&:to_s).map(&:downcase).include?(request_method.to_s.downcase)
    end

    def uri
      @uri ||= Addressable::URI.parse(to)
    end

    def handle(request, response)
      ForwardHandler.new(self, request, response)
    end
  end
end
