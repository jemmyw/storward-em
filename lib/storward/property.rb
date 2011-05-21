module Storward
  module Property
    def property(*properties)
      options = properties.last.is_a?(Hash) ? properties.pop : {}
      args = options[:splat] ? "*v" : "v=nil"
      cond = options[:splat] ? "v.empty?" : "v.nil?"

      properties.each do |name|
        class_eval %Q{
          def #{name}(#{args})
            if #{cond}
              @#{name}
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
