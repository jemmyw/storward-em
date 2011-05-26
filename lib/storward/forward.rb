module Storward  
  class Forward
    extend Property

    attr_accessor :path
    attr_accessor :methods
    attr_accessor :config

    def initialize(path, options = {})
      self.path = path
      self.methods = options.delete(:method).to_a
      self.methods += options.delete(:methods).to_a

      self.config = Proc.new
    end

    def handles?(request)
      path_match?(request.path_info) && method_match?(request.method)
    end

    def path_match?(path_info)
      path_info =~ path
    end

    def method_match?(request_method)
      methods.nil? || methods.empty? || methods.map(&:to_s).map(&:downcase).include?(request_method.to_s.downcase)
    end

    def uri
      @uri ||= Addressable::URI.parse(to)
    end

    def handle(request, response)
      matches = path.match(request.path_info).to_a[1..-1]
      ForwardHandler.new(matches, request, response, &config)
    end
  end
end
