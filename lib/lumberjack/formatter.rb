# frozen_string_literals: true

module Lumberjack
  # This class controls the conversion of log entry messages into a loggable format. This allows you
  # to log any object you want and have the logging system deal with converting it into a string.
  #
  # Formats are added to a Formatter by associating them with a class using the +add+ method. Formats
  # are any object that responds to the +call+ method.
  #
  # By default, all object will be converted to strings using their inspect method except for Strings
  # and Exceptions. Strings are not converted and Exceptions are converted using the ExceptionFormatter.
  #
  # Enumerable objects (including Hash and Array) will call the formatter recursively for each element.
  class Formatter
    require_relative "formatter/date_time_formatter.rb"
    require_relative "formatter/exception_formatter.rb"
    require_relative "formatter/id_formatter.rb"
    require_relative "formatter/inspect_formatter.rb"
    require_relative "formatter/object_formatter.rb"
    require_relative "formatter/pretty_print_formatter.rb"
    require_relative "formatter/string_formatter.rb"
    require_relative "formatter/structured_formatter.rb"

    def initialize
      @class_formatters = {}
      @module_formatters = {}
      @_default_formatter = InspectFormatter.new
      structured_formatter = StructuredFormatter.new(self)
      add(String, :object)
      add(Numeric, :object)
      add(TrueClass, :object)
      add(FalseClass, :object)
      add(Object, @_default_formatter)
      add(Exception, :exception)
      add(Enumerable, structured_formatter)
    end

    # Add a formatter for a class. The formatter can be specified as either an object
    # that responds to the +call+ method or as a symbol representing one of the predefined
    # formatters, or as a block to the method call.
    #
    # The predefined formatters are: :inspect, :string, :exception, and :pretty_print.
    #
    # === Examples
    #
    #   # Use a predefined formatter
    #   formatter.add(MyClass, :pretty_print)
    #
    #   # Pass in a formatter object
    #   formatter.add(MyClass, Lumberjack::Formatter::PrettyPrintFormatter.new)
    #
    #   # Use a block
    #   formatter.add(MyClass){|obj| obj.humanize}
    #
    #   # Add statements can be chained together
    #   formatter.add(MyClass, :pretty_print).add(YourClass){|obj| obj.humanize}
    def add(klass, formatter = nil, &block)
      formatter ||= block
      if formatter.is_a?(Symbol)
        formatter_class_name = "#{formatter.to_s.gsub(/(^|_)([a-z])/){|m| $~[2].upcase}}Formatter"
        formatter = Formatter.const_get(formatter_class_name).new
      end
      if klass.is_a?(Class)
        @class_formatters[klass] = formatter
      else
        @module_formatters[klass] = formatter
      end
      self
    end

    # Remove the formatter associated with a class. Remove statements can be chained together.
    def remove(klass)
      if klass.is_a?(Class)
        @class_formatters.delete(klass)
      else
        @module_formatters.delete(klass)
      end
      self
    end
    
    # Remove all formatters including the default formatter. Can be chained to add method calls.
    def clear
      @class_formatters.clear
      @module_formatters.clear
      self
    end

    # Format a message object as a string.
    def format(message)
      formatter_for(message.class).call(message)
    end

    # Compatibility with the Logger::Formatter signature. This method will just convert the message
    # object to a string and ignores the other parameters.
    def call(severity, timestamp, progname, msg)
      "#{format(msg)}#{Lumberjack::LINE_SEPARATOR}"
    end

    private

    # Find the formatter for a class by looking it up using the class hierarchy.
    def formatter_for(klass) #:nodoc:
      check_modules = true
      while klass != nil do
        formatter = @class_formatters[klass]
        return formatter if formatter

        if check_modules
          _, formatter = @module_formatters.detect { |mod, f| klass.include?(mod) }
          check_modules = false
          return formatter if formatter
        end

        klass = klass.superclass
      end
      @_default_formatter
    end
  end
end
