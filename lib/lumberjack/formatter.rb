# frozen_string_literal: true

require_relative "formatter_registry"

module Lumberjack
  # Formatter controls the conversion of log entry messages into a loggable format, allowing you
  # to log any object type and have the logging system handle the string conversion automatically.
  #
  # The formatter system works by associating formatting rules with specific classes using the {#add} method.
  # When an object is logged, the formatter finds the most specific formatter for that object's class
  # hierarchy and applies it to convert the object into a string representation.
  #
  # ## Default Behavior
  #
  # By default, the formatter includes these mappings:
  # - **Object**: Uses `inspect` method for a readable representation
  # - **Exception**: Uses {ExceptionFormatter} to format stack traces and error details
  # - **Enumerable** (Hash, Array, etc.): Uses {StructuredFormatter} to recursively format elements
  # - **String**: No formatting (passed through unchanged)
  #
  # ## Formatter Types
  #
  # Formatters can be:
  # - **Predefined formatters**: Accessed by symbol (e.g., `:pretty_print`, `:truncate`)
  # - **Custom objects**: Any object responding to `#call(object)`
  # - **Blocks**: Inline formatting logic
  # - **Classes**: Instantiated automatically with optional arguments
  #
  # ## Performance Optimization
  #
  # The formatter includes optimizations for common primitive types (String, Integer, Float, Boolean)
  # to avoid unnecessary formatting overhead when custom formatters aren't defined for these types.
  #
  # @example Basic formatter usage
  #   formatter = Lumberjack::Formatter.new
  #   formatter.add(MyClass, :pretty_print)
  #   formatter.add(SecretClass) { |obj| "[REDACTED]" }
  #   result = formatter.format(my_object)
  #
  # @example Building a custom formatter
  #   formatter = Lumberjack::Formatter.build do |config|
  #     config.add(User, :id)  # Only log user IDs
  #     config.add(Password) { |pwd| "[HIDDEN]" }  # Hide password values
  #     config.add(BigDecimal, :round, 2)  # Round decimals to 2 places
  #   end
  class Formatter
    require_relative "formatter/date_time_formatter"
    require_relative "formatter/exception_formatter"
    require_relative "formatter/id_formatter"
    require_relative "formatter/inspect_formatter"
    require_relative "formatter/multiply_formatter"
    require_relative "formatter/object_formatter"
    require_relative "formatter/pretty_print_formatter"
    require_relative "formatter/redact_formatter"
    require_relative "formatter/round_formatter"
    require_relative "formatter/string_formatter"
    require_relative "formatter/strip_formatter"
    require_relative "formatter/structured_formatter"
    require_relative "formatter/tags_formatter"
    require_relative "formatter/truncate_formatter"
    require_relative "formatter/tagged_message"

    class << self
      # Build a new formatter using a configuration block. The block receives the new formatter
      # as a parameter, allowing you to configure it with methods like `add`, `remove`, etc.
      #
      # @yield [formatter] A block that configures the formatter.
      # @return [Lumberjack::Formatter] A new configured formatter.
      #
      # @example
      #   formatter = Lumberjack::Formatter.build do |config|
      #     config.add(User, :id)  # Only show user IDs
      #     config.add(SecretToken) { |token| "[REDACTED]" }
      #     config.remove(Exception)  # Don't format exceptions specially
      #   end
      def build(&block)
        formatter = new
        block&.call(formatter)
        formatter
      end

      # Create a new empty formatter with no mappings. This is an alias for #new.
      #
      # @return [Lumberjack::Formatter] A new formatter with no default mappings.
      # @deprecated Use #new instead.
      def empty
        Utils.deprecated("Formatter.empty", "Lumberjack::Formatter.empty is deprecated; use new instead.") do
          new
        end
      end

      # Create a new formatter with default mappings.
      #
      #   Object: inspect formatter
      #   Exception: exception formatter
      #   Enumerable: structured formatter
      #
      # @return [Lumberjack::Formatter] A new formatter with default mappings.
      def default
        build do |config|
          config.add(Object, :inspect)
          config.add(Exception, :exception)
          config.add(Enumerable, :structured)
        end
      end
    end

    # Create a new formatter with default mappings for common Ruby types.
    # The default configuration provides sensible formatting for most use cases:
    # - Object: Uses inspect for debugging-friendly output
    # - Exception: Formats with stack trace details
    # - Enumerable: Recursively formats collections (Arrays, Hashes, etc.)
    #
    # @return [Lumberjack::Formatter] A new formatter with default mappings.
    def initialize
      @class_formatters = {}
      @has_string_formatter = false
      @has_numeric_formatter = false
      @has_boolean_formatter = false
    end

    # Add a formatter for a specific class or classes. The formatter determines how objects
    # of that class will be converted to strings when logged.
    #
    # ## Formatter Types
    #
    # The formatter can be specified in several ways:
    # - **Symbol**: References a predefined formatter (see list below)
    # - **Class**: Will be instantiated with optional arguments
    # - **Object**: Must respond to `#call(object)` method
    # - **Block**: Inline formatting logic
    #
    # ## Formatter Registry
    #
    # Formatters can be referenced by name from the formatter registry. These formatters
    # are available out of the box. Some of them require an argument to be provided as well.
    #
    # - `:date_time` - Formats time objects with a customizable format (takes the format string as an argument)
    # - `:exception` - Formats exceptions with stack trace details
    # - `:id` - Extracts object ID or specified ID field
    # - `:inspect` - Uses Ruby's inspect method for debugging output
    # - `:multiply` - Multiplies numeric values by a factor (requires the factor as an argument)
    # - `:object` - Generic object formatter with custom methods
    # - `:pretty_print` - Pretty-prints objects using PP library
    # - `:redact` - Redacts sensitive information from objects
    # - `:round` - Rounds numeric values to specified precision (takes the precision as an argument; defaults to 3 decimal places)
    # - `:string` - Converts objects to strings using to_s
    # - `:strip` - Strips whitespace from string representations
    # - `:structured` - Recursively formats structured data (Arrays, Hashes)
    # - `:tags` - Formats an array or hash of values in the format "[a] [b] [c=d]"
    # - `:truncate` - Truncates long strings to specified length (takes the length as an argument)
    #
    # ## Class Specification
    #
    # Classes can be specified as:
    # - **Class objects**: Direct class references
    # - **Arrays**: Multiple classes at once
    # - **Strings**: Class names to avoid loading dependencies
    #
    # @param klass [Class, Module, String, Array<Class, Module, String>] The class(es) to format.
    # @param formatter [Symbol, Class, #call, nil] The formatter to use.
    # @param args [Array] Arguments passed to formatter constructor (when formatter is a Class).
    # @yield [obj] Block-based formatter that receives the object to format.
    # @yieldparam obj [Object] The object to format.
    # @yieldreturn [String] The formatted string representation.
    # @return [self] Returns self for method chaining.
    #
    # @example Using predefined formatters
    #   formatter.add(Float, :round, 2)  # Round floats to 2 decimal places
    #   formatter.add(Time, :date_time, "%Y-%m-%d")  # Custom time format
    #   formatter.add([User, Admin], :id)  # Show only IDs for user objects
    #
    # @example Using custom formatters
    #   formatter.add(MyClass, MyFormatter.new)  # Custom formatter object
    #   formatter.add(SecretData) { |obj| "[REDACTED]" }  # Block formatter
    #   formatter.add("BigDecimal", RoundFormatter, 4)  # Class with arguments
    #
    # @example Method chaining
    #   formatter.add(User, :id)
    #            .add(Password) { |pwd| "[HIDDEN]" }
    #            .add(BigDecimal, :round, 2)
    def add(klass, formatter = nil, *args, &block)
      formatter ||= block

      return remove(klass) if formatter.nil?

      if formatter.is_a?(Symbol)
        formatter = FormatterRegistry.formatter(formatter, *args)
      elsif formatter.is_a?(Class)
        formatter = formatter.new(*args)
      end

      raise ArgumentError.new("formatter must respond to call") unless formatter.respond_to?(:call)

      Array(klass).each do |k|
        @class_formatters[k.to_s] = formatter
      end

      set_optimized_flags!

      self
    end

    # Remove formatter associations for one or more classes. This reverts the classes
    # to use the default Object formatter (inspect method) or no formatting if no default exists.
    #
    # @param klass [Class, Module, String, Array<Class, Module, String>] The class(es) to remove formatters for.
    # @return [self] Returns self for method chaining.
    def remove(klass)
      Array(klass).each do |k|
        @class_formatters.delete(k.to_s)
      end

      set_optimized_flags!

      self
    end

    # Extend this formatter by merging the formats defined in the provided formatter into this one.
    #
    # @param formatter [Lumberjack::Formatter] The formatter to merge.
    # @return [self] Returns self for method chaining.
    def include(formatter)
      unless formatter.is_a?(Lumberjack::Formatter)
        raise ArgumentError.new("formatter must be a Lumberjack::Formatter")
      end

      formatter.instance_variable_get(:@class_formatters).each do |class_name, fmttr|
        add(class_name, fmttr)
      end

      self
    end

    # Extend this formatter by adding the formats defined in the provided formatter into this one.
    # Formats defined in this formatter will take precedence and not be overridden.
    #
    # @param formatter [Lumberjack::Formatter] The formatter to merge.
    # @return [self] Returns self for method chaining.
    def prepend(formatter)
      unless formatter.is_a?(Lumberjack::Formatter)
        raise ArgumentError.new("formatter must be a Lumberjack::Formatter")
      end

      formatter.instance_variable_get(:@class_formatters).each do |class_name, fmttr|
        add(class_name, fmttr) unless @class_formatters.include?(class_name)
      end

      self
    end

    # Remove all formatter associations, including defaults. This creates a completely
    # empty formatter where all objects will be passed through unchanged.
    #
    # @return [self] Returns self for method chaining.
    def clear
      @class_formatters.clear
      set_optimized_flags!

      self
    end

    # Check if the formatter has any registered formatters.
    #
    # @return [Boolean] true if no formatters are registered, false otherwise.
    def empty?
      @class_formatters.empty?
    end

    # Format an object by applying the appropriate formatter based on its class hierarchy.
    # The formatter searches up the class hierarchy to find the most specific formatter available.
    #
    # @param value [Object] The object to format.
    # @return [Object] The formatted representation (usually a String).
    def format(value)
      # These primitive types are the most common in logs and so are optimized here
      # for the normal case where a custom formatter has not been defined.
      case value
      when String
        return value unless @has_string_formatter
      when Integer, Float
        return value unless @has_numeric_formatter
      when Numeric
        if defined?(BigDecimal) && value.is_a?(BigDecimal)
          return value unless @has_numeric_formatter
        end
      when true, false
        return value unless @has_boolean_formatter
      end

      if value.respond_to?(:to_log_format) && !@class_formatters.include?(value.class.name)
        return value.to_log_format
      end

      formatter = formatter_for(value.class)
      value = formatter.call(value) if formatter&.respond_to?(:call)
      value
    rescue SystemStackError, StandardError => e
      error_message = e.class.name
      error_message = "#{error_message} #{e.message}" if e.message && e.message != ""
      warn("<Error formatting #{value.class.name}: #{error_message}>")
      "<Error formatting #{value.class.name}: #{error_message}>"
    end

    # Compatibility method for Ruby's standard Logger::Formatter interface. This allows
    # the Formatter to be used directly as a logger formatter, though it only uses the
    # message parameter and ignores severity, timestamp, and progname.
    #
    # @param severity [Integer, String, Symbol] The log severity (ignored).
    # @param timestamp [Time] The log timestamp (ignored).
    # @param progname [String] The program name (ignored).
    # @param msg [Object] The message object to format.
    # @return [String] The formatted message with line separator.
    def call(severity, timestamp, progname, msg)
      formatted_message = format(msg)
      formatted_message = formatted_message.message if formatted_message.is_a?(MessageAttributes)
      "#{formatted_message}#{Lumberjack::LINE_SEPARATOR}"
    end

    # Find the most appropriate formatter for a class by searching up the class hierarchy.
    # Returns the first formatter found by walking through the class's ancestors.
    #
    # @param klass [Class] The class to find a formatter for.
    # @return [#call, nil] The formatter object, or nil if no formatter is found.
    # @api private
    def formatter_for(klass)
      return nil if @class_formatters.empty?

      unless klass.is_a?(Module)
        begin
          klass = Object.const_get(klass.to_s)
        rescue NameError
          return @class_formatters[klass.to_s]
        end
      end

      formatter = nil
      has_to_log_format = klass.public_method_defined?(:to_log_format) if klass.is_a?(Module)
      klass.ancestors.detect do |ancestor|
        break if has_to_log_format && ancestor == Object

        formatter = @class_formatters[ancestor.name]
        break if formatter
      end
      formatter
    end

    # Update internal optimization flags based on currently registered formatters.
    # This enables fast-path optimization for common primitive types.
    #
    # @return [void]
    # @api private
    def set_optimized_flags!
      @has_string_formatter = @class_formatters.include?("String")
      @has_numeric_formatter = @class_formatters.slice("Integer", "Float", "BigDecimal", "Numeric").any?
      @has_boolean_formatter = @class_formatters.include?("TrueClass") || @class_formatters.include?("FalseClass")
    end
  end
end
