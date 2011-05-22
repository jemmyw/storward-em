module Storward
  module Property
    def property_default(name)
      @property_defaults ? @property_defaults[name] : nil
    end

    def property(*properties)
      options = properties.last.is_a?(Hash) ? properties.pop : {}
      args = options[:splat] ? "*v" : "v=nil"
      cond = options[:splat] ? "v.empty?" : "v.nil?"
      default = options[:default]

      @property_defaults ||= {}

      properties.each do |name|
        @property_defaults[name] = default if default
        
        class_eval %Q{
          def #{name}(#{args})
            if #{cond}
              @#{name} || self.class.property_default(:#{name})
            else
              @#{name} = v; 
            end
          end

          def #{name}?
            !!@#{name}
          end
        }
      end
    end
  end
end
