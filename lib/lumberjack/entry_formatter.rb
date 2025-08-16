# frozen_string_literal: true

module Lumberjack
  # This class provides an unified interface for formatting log entry details. It combines
  # two kinds of formatters and returns an entry with all of the raw objects formatted.
  #
  # 1. A `Lumberjack::Formatter` which is used to format log messages.
  # 2. A `Lumberjack::TagFormatter` which is used to format log tags.
  #
  # It also provides an interface for managing all both formatters with chained methods.
  #
  # @example
  #
  # formatter = Lumberjack::EntryFormatter.new
  #   .add(ActiveRecord::Base, :id) # format models with the id formatter
  #   .add(MyClass) { |obj| "Custom format for #{obj}" }
  #   .tags do
  #     add("status") { |obj| "Status: #{obj}" } # custom formatter for the "status" tag
  #     add(Exception) { |obj| {kind: obj.class.name, message: obj.message} } # custom formatter for exceptions in tags
  #   end
  class EntryFormatter
    attr_accessor :message_formatter

    attr_accessor :tag_formatter

    def initialize(message_formatter: nil, tag_formatter: nil)
      if message_formatter.nil? || message_formatter == :default
        message_formatter = Lumberjack::Formatter.new
      elsif message_formatter == :none
        message_formatter = Lumberjack::Formatter.empty
      end

      @message_formatter = message_formatter
      @tag_formatter = tag_formatter
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

    # Switch context to the tag formatter. Within the block all method calls will be made to
    # the tag formatter.
    #
    # @param block [Proc] The block to execute within the tag formatter context.
    # @return [Lumberjack::EntryFormatter] The entry formatter.
    #
    # @example
    #   formatter.tags do
    #     add("status") { |obj| "Status: #{obj}" } # Adds to the tag formatter
    #   end
    def tags(&block)
      @tag_formatter ||= Lumberjack::TagFormatter.new
      tag_formatter.instance_exec(&block) if block
      self
    end

    # Format the message and tags.
    #
    # @param message [Object, nil] The log message.
    # @param tags [Hash, nil] The log tags.
    # @return [Array<Object, Hash>] The formatted message and tags.
    def format(message, tags)
      message = message.call if message.is_a?(Proc)
      if message.respond_to?(:to_log_format, true) && message.method(:to_log_format).parameters.empty?
        message = message.to_log_format
      elsif message_formatter
        message = message_formatter.format(message)
      end

      message_tags = nil
      if message.is_a?(Formatter::TaggedMessage)
        message_tags = message.tags
        message = message.message
      end
      message_tags = Utils.flatten_tags(message_tags) if message_tags

      tags = merge_tags(tags, message_tags) if message_tags
      tags = Tags.expand_runtime_values(tags)
      tags = tag_formatter.format(tags) if tags && tag_formatter

      [message, tags]
    end

    def call(severity, timestamp, progname, msg)
      message_formatter&.call(severity, timestamp, progname, msg)
    end

    private

    def merge_tags(current_tags, tags)
      if current_tags.nil? || current_tags.empty?
        tags
      elsif tags.nil?
        current_tags
      else
        current_tags.merge(tags)
      end
    end

    # TODO: need this in logger
    def accepts_tags_parameter?(formatter)
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
