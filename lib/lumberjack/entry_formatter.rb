# frozen_string_literal: true

module Lumberjack
  # This class provides an unified interface for formatting log entry details. It combines
  # two kinds of formatters and returns an entry with all of the raw objects formatted.
  #
  # 1. A `Lumberjack::Formatter` which is used to format log messages.
  # 2. A `Lumberjack::attributeFormatter` which is used to format log attributes.
  #
  # It also provides an interface for managing all both formatters with chained methods.
  #
  # @example
  #
  # formatter = Lumberjack::EntryFormatter.new
  #   .add(ActiveRecord::Base, :id) # format models with the id formatter
  #   .add(MyClass) { |obj| "Custom format for #{obj}" }
  #   .attributes do
  #     add("status") { |obj| "Status: #{obj}" } # custom formatter for the "status" attribute
  #     add(Exception) { |obj| {kind: obj.class.name, message: obj.message} } # custom formatter for exceptions in attributes
  #   end
  class EntryFormatter
    attr_accessor :message_formatter

    attr_accessor :attribute_formatter

    class << self
      # Build a new entry formatter using the given block. The block will be yielded to with
      # the new formatter in context.
      #
      # @example
      #   Lumberjack::EntryFormatter.build do
      #     add(ActiveRecord::Base, :id) # format models with the id formatter
      #     add(MyClass) { |obj| "Custom format for #{obj}" }
      #     attributes do
      #       add("status") { |obj| "Status: #{obj}" } # custom formatter for the "status" attribute
      #       add(Exception) { |obj| {kind: obj.class.name, message: obj.message} } # custom formatter for exceptions in attributes
      #     end
      #   end
      def build(message_formatter: nil, attribute_formatter: nil, &block)
        formatter = new(message_formatter: message_formatter, attribute_formatter: attribute_formatter)
        formatter.instance_exec(&block) if block
        formatter
      end
    end

    def initialize(message_formatter: nil, attribute_formatter: nil)
      if message_formatter.nil? || message_formatter == :default
        message_formatter = Lumberjack::Formatter.new
      elsif message_formatter == :none
        message_formatter = Lumberjack::Formatter.empty
      end

      @message_formatter = message_formatter
      @attribute_formatter = attribute_formatter
    end

    # Add a message formatter for a class or module.
    #
    # @param klass [Class, Module, String, Array<Class, Module, String>] The class or module to add the formatter for.
    # @param formatter [Lumberjack::Formatter, #call, nil] The formatter to use.
    # @param args [Array] Arguments to pass to the formatter when it is initialized. This is only relevant
    #   when klass is a Class or Symbol.
    # @param block [Proc] A block to use as the formatter
    # @return [Lumberjack::EntryFormatter] The entry formatter.
    def add(klass, formatter = nil, *args, &block)
      @message_formatter.add(klass, formatter, *args, &block)
      self
    end

    # Remove a message formatter for a class or module.
    #
    # @param klass [Class, Module, String, Array<Class, Module, String>] The class or module to remove the formatter for.
    # @return [Lumberjack::EntryFormatter] The entry formatter.
    def remove(klass)
      @message_formatter.remove(klass)
      self
    end

    # Switch context to the attribute formatter. Within the block all method calls will be made to
    # the attribute formatter.
    #
    # @param block [Proc] The block to execute within the attribute formatter context.
    # @return [Lumberjack::EntryFormatter] The entry formatter.
    #
    # @example
    #   formatter.attributes do
    #     add("status") { |obj| "Status: #{obj}" } # Adds to the attribute formatter
    #   end
    def attributes(&block)
      @attribute_formatter ||= Lumberjack::AttributeFormatter.new
      attribute_formatter.instance_exec(&block) if block
      self
    end

    # Format the message and attributes.
    #
    # @param message [Object, nil] The log message.
    # @param attributes [Hash, nil] The log attributes.
    # @return [Array<Object, Hash>] The formatted message and attributes.
    def format(message, attributes)
      message = message.call if message.is_a?(Proc)
      if message.respond_to?(:to_log_format) && message.method(:to_log_format).parameters.empty?
        message = message.to_log_format
      elsif message_formatter
        message = message_formatter.format(message)
      end

      message_attributes = nil
      if message.is_a?(Formatter::TaggedMessage)
        message_attributes = message.attributes
        message = message.message
      end
      message_attributes = Utils.flatten_attributes(message_attributes) if message_attributes

      attributes = merge_attributes(attributes, message_attributes) if message_attributes
      attributes = AttributesHelper.expand_runtime_values(attributes)
      attributes = attribute_formatter.format(attributes) if attributes && attribute_formatter

      [message, attributes]
    end

    def call(severity, timestamp, progname, msg)
      message_formatter&.call(severity, timestamp, progname, msg)
    end

    private

    def merge_attributes(current_attributes, attributes)
      if current_attributes.nil? || current_attributes.empty?
        attributes
      elsif attributes.nil?
        current_attributes
      else
        current_attributes.merge(attributes)
      end
    end

    # TODO: need this in logger
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
