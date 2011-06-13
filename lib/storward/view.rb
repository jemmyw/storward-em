require 'erb'

module Storward
  class View
    def initialize(path, layout = nil, variables = {})
      variables.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
      @template = File.join(File.dirname(__FILE__), 'views', "#{path}.html.erb")

      if layout
        @layout = View.new("layouts/#{layout}", nil, variables)
      end
    end

    def render
      begin
        b = binding

        if @layout
          @layout.render { erb.result(b) }
        else
          erb.result(b)
        end
      rescue Exception => e
        "Exception: #{e.to_s}"
      end
    end

    private

    def erb
      @erb ||= ERB.new(read_template)
    end

    def read_template
      File.read(@template)
    end
  end
end
