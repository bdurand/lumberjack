# frozen_string_literal: true

module Lumberjack
  # EntryFormatter provides a unified interface for formatting complete log entries by combining
  # message formatting and attribute formatting into a single, coordinated system.
  #
  # This class serves as the central formatting coordinator in the Lumberjack logging pipeline,
  # bringing together two specialized formatters:
  # 1. **Message Formatter** ({Lumberjack::Formatter}) - Formats the main log message content
  # 2. **Attribute Formatter** ({Lumberjack::AttributeFormatter}) - Formats key-value attribute pairs
  #
  # ## Architecture
  #
  # The EntryFormatter acts as a facade that:
  # - Delegates message formatting to a Formatter instance
  # - Delegates attribute formatting to an AttributeFormatter instance
  # - Provides a unified configuration interface through method chaining
  # - Handles the coordination between message and attribute formatting
  # - Manages special message types like MessageAttributes that carry embedded attributes
  #
  # @example Complete entry formatting setup
  #   formatter = Lumberjack::EntryFormatter.build do
  #     # Message formatting (delegates to Formatter)
  #     add(ActiveRecord::Base, :id)
  #     add(Exception, :exception)
  #     add(Time, :date_time, "%Y-%m-%d %H:%M:%S")
  #
  #     # Attribute formatting (delegates to AttributeFormatter)
  #     attributes do
  #       add("password") { |value| "[REDACTED]" }
  #       add("user_id", :id)
  #       add(Time, :date_time, "%Y-%m-%d")
  #       default { |value| value.to_s.strip }
  #     end
  #   end
  #
  # @example Using with a logger
  #   logger = Lumberjack::Logger.new(STDOUT, formatter: formatter)
  #   logger.info("User login", user: user_object, timestamp: Time.now)
  #   # Both the message and attributes are formatted according to the rules
  #
  # @see Lumberjack::Formatter
  # @see Lumberjack::AttributeFormatter
  # @see Lumberjack::Logger
  class EntryFormatter
    # The message formatter used to format log message content.
    # @return [Lumberjack::Formatter] The message formatter instance.
    attr_accessor :message_formatter

    # The attribute formatter used to format log entry attributes.
    # @return [Lumberjack::AttributeFormatter] The attribute formatter instance.
    attr_accessor :attribute_formatter

    class << self
      # Build a new entry formatter using a configuration block. The block is evaluated
      # in the context of the new formatter, allowing direct use of configuration methods.
      #
      # @param message_formatter [Lumberjack::Formatter, Symbol, nil] The message formatter to use.
      #   Can be a Formatter instance, :default for standard formatter, :none for empty formatter, or nil.
      # @param attribute_formatter [Lumberjack::AttributeFormatter, nil] The attribute formatter to use.
      # @yield [formatter] A block that configures the entry formatter.
      # @return [Lumberjack::EntryFormatter] A new configured entry formatter.
      #
      # @example
      #   formatter = Lumberjack::EntryFormatter.build do
      #     add(User, :id)  # Message formatting
      #     add(Time, :date_time, "%Y-%m-%d")
      #
      #     attributes do  # Attribute formatting
      #       add("password") { "[REDACTED]" }
      #       add(Exception) { |e| {error: e.class.name, message: e.message} }
      #     end
      #   end
      def build(message_formatter: nil, attribute_formatter: nil, &block)
        formatter = new(message_formatter: message_formatter, attribute_formatter: attribute_formatter)
        formatter.instance_exec(&block) if block
        formatter
      end
    end

    # Create a new entry formatter with the specified message and attribute formatters.
    #
    # @param message_formatter [Lumberjack::Formatter, Symbol, nil] The message formatter to use:
    #   - Formatter instance: Used directly
    #   - :default or nil: Creates a new Formatter with default mappings
    #   - :none: Creates an empty Formatter with no default mappings
    # @param attribute_formatter [Lumberjack::AttributeFormatter, nil] The attribute formatter to use.
    #   If nil, no attribute formatting will be performed unless configured later.
    def initialize(message_formatter: nil, attribute_formatter: nil)
      if message_formatter == :default
        message_formatter = Lumberjack::Formatter.default
      elsif message_formatter.nil?
        message_formatter = Lumberjack::Formatter.new
      end

      @message_formatter = message_formatter
      @attribute_formatter = attribute_formatter
    end

    # Add a message formatter for specific classes or modules. This method delegates to the
    # underlying message formatter, allowing you to configure message formatting rules
    # through the EntryFormatter interface.
    #
    # @param klass [Class, Module, String, Array<Class, Module, String>] The class(es) to format.
    # @param formatter [Symbol, Class, #call, nil] The formatter to use.
    # @param args [Array] Arguments to pass to the formatter constructor (when formatter is a Class).
    # @yield [obj] Block-based formatter that receives the object to format.
    # @return [Lumberjack::EntryFormatter] Returns self for method chaining.
    #
    # @example Adding message formatters
    #   formatter.add(User, :id)  # Use ID formatter for User objects
    #   formatter.add(Time, :date_time, "%Y-%m-%d")  # Custom time format
    #   formatter.add(SecretToken) { |token| "[TOKEN]" }  # Block formatter
    #
    # @see Lumberjack::Formatter#add
    def add(klass, formatter = nil, *args, &block)
      @message_formatter.add(klass, formatter, *args, &block)
      self
    end

    # Remove a message formatter for specific classes or modules. This method delegates
    # to the underlying message formatter.
    #
    # @param klass [Class, Module, String, Array<Class, Module, String>] The class(es) to remove formatters for.
    # @return [Lumberjack::EntryFormatter] Returns self for method chaining.
    #
    # @see Lumberjack::Formatter#remove
    def remove(klass)
      @message_formatter.remove(klass)
      self
    end

    # Switch context to attribute formatter configuration. Within the block, all method calls
    # are delegated to the attribute formatter, allowing you to configure attribute formatting
    # rules using the AttributeFormatter API.
    #
    # If no attribute formatter exists, one will be created automatically.
    #
    # @yield [attribute_formatter] Block executed in the attribute formatter context.
    # @return [Lumberjack::EntryFormatter] Returns self for method chaining.
    #
    # @example Configuring attribute formatting
    #   formatter.attributes do
    #     add("password") { |value| "[REDACTED]" }
    #     add("email") { |email| email.downcase }
    #     add(Time, :date_time, "%Y-%m-%d")
    #     default { |value| value.to_s.strip }
    #   end
    #
    # @see Lumberjack::AttributeFormatter
    def attributes(&block)
      @attribute_formatter ||= Lumberjack::AttributeFormatter.new
      attribute_formatter.instance_exec(&block) if block
      self
    end

    # Extend this formatter by merging the formats defined in the provided formatter into this one.
    #
    # @param formatter [Lumberjack::EntryFormatter] The formatter to merge.
    # @return [self] Returns self for method chaining.
    def include(formatter)
      unless formatter.is_a?(Lumberjack::EntryFormatter)
        raise ArgumentError.new("formatter must be a Lumberjack::EntryFormatter")
      end

      @message_formatter ||= Lumberjack::Formatter.new
      @message_formatter.include(formatter.message_formatter)

      @attribute_formatter ||= Lumberjack::AttributeFormatter.new
      @attribute_formatter.include(formatter.attribute_formatter)

      self
    end

    # Format a complete log entry by applying both message and attribute formatting.
    # This is the main method that coordinates the formatting of both the message content
    # and any associated attributes.
    #
    # @param message [Object, Proc, nil] The log message to format. Can be any object, a Proc that returns the message, or nil.
    # @param attributes [Hash, nil] The log entry attributes to format.
    # @return [Array<Object, Hash>] A two-element array containing [formatted_message, formatted_attributes].
    def format(message, attributes)
      message = message.call if message.is_a?(Proc)
      message = message_formatter.format(message) if message_formatter.respond_to?(:format)

      message_attributes = nil
      if message.is_a?(MessageAttributes)
        message_attributes = message.attributes
        message = message.message
      end
      message_attributes = Utils.flatten_attributes(message_attributes) if message_attributes

      attributes = merge_attributes(attributes, message_attributes) if message_attributes
      attributes = AttributesHelper.expand_runtime_values(attributes)
      attributes = attribute_formatter.format(attributes) if attributes && attribute_formatter

      [message, attributes]
    end

    # Compatibility method for Ruby's standard Logger::Formatter interface. This delegates
    # to the message formatter's call method for basic Logger compatibility.
    #
    # @param severity [Integer, String, Symbol] The log severity (passed to message formatter).
    # @param timestamp [Time] The log timestamp (passed to message formatter).
    # @param progname [String] The program name (passed to message formatter).
    # @param msg [Object] The message object to format (passed to message formatter).
    # @return [String, nil] The formatted message string, or nil if no message formatter.
    #
    # @see Lumberjack::Formatter#call
    def call(severity, timestamp, progname, msg)
      message_formatter&.call(severity, timestamp, progname, msg)
    end

    private

    # Merge two attribute hashes, handling nil values gracefully.
    # Used to combine explicit log attributes with attributes embedded in MessageAttributes objects.
    #
    # @param current_attributes [Hash, nil] The primary attributes hash.
    # @param attributes [Hash, nil] Additional attributes to merge in.
    # @return [Hash, nil] The merged attributes hash, or nil if both inputs are nil/empty.
    # @api private
    def merge_attributes(current_attributes, attributes)
      if current_attributes.nil? || current_attributes.empty?
        attributes
      elsif attributes.nil?
        current_attributes
      else
        current_attributes.merge(attributes)
      end
    end

    # Check if a formatter accepts an attributes parameter in its call method.
    # This is used for determining formatter compatibility but is currently unused (TODO).
    #
    # @param formatter [#call] The formatter to check.
    # @return [Boolean] true if the formatter accepts 5+ parameters or has a splat parameter.
    # @api private
    # @todo This method needs to be integrated into the logger functionality.
    def accepts_attributes_parameter?(formatter)
      method_obj = if formatter.is_a?(Proc)
        formatter
      elsif formatter.respond_to?(:call)
        formatter.method(:call)
      end
      return false unless method_obj

      params = method_obj.parameters
      positional = params.slice(:req, :opt)
      has_splat = params.any? { |type, _| type == :rest }
      positional_count = positional.size
      positional_count >= 5 || has_splat
    end
  end
end
