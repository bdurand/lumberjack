# frozen_string_literal: true

module Lumberjack
  # Class for formatting tags. You can register a default formatter and tag
  # name specific formatters. Formatters can be either `Lumberjack::Formatter`
  # objects or any object that responds to `call`.
  #
  # tag_formatter = Lumberjack::TagFormatter.new.default(Lumberjack::Formatter.new)
  # tag_formatter.add(["password", "email"]) { |value| "***" }
  # tag_formatter.add("finished_at", Lumberjack::Formatter::DateTimeFormatter.new("%Y-%m-%dT%H:%m:%S%z"))
  class TagFormatter
    def initialize
      @formatters = {}
      @class_formatters = {}
      @default_formatter = nil
    end

    # Add a default formatter applied to all tag values. This can either be a Lumberjack::Formatter
    # or an object that responds to `call` or a block.
    #
    # @param [Lumberjack::Formatter, #call, nil] formatter The formatter to use.
    #    If this is nil, then the block will be used as the formatter.
    # @return [Lumberjack::TagFormatter] self
    def default(formatter = nil, &block)
      formatter ||= block
      formatter = dereference_formatter(formatter)
      @default_formatter = formatter
      self
    end

    # Remove the default formatter.
    #
    # @return [Lumberjack::TagFormatter] self
    def remove_default
      @default_formatter = nil
      self
    end

    # Add a formatter for specific tag names or object classes. This can either be a Lumberjack::Formatter
    # or an object that responds to `call` or a block. The default formatter will not be
    # applied. The formatter will be applied if it matches either a tag name or if the tag value
    # is an instance of a registered class.
    #
    # @param [String, Module, Array<String, Module>] names_or_classes The tag names or object classes
    #   to apply the formatter to.
    # @param [Lumberjack::Formatter, #call, nil] formatter The formatter to use.
    #    If this is nil, then the block will be used as the formatter.
    # @return [Lumberjack::TagFormatter] self
    #
    # @example
    #  tag_formatter.add("password", &:redact)
    def add(names_or_classes, formatter = nil, &block)
      formatter ||= block
      formatter = dereference_formatter(formatter)
      if formatter.nil?
        remove(key)
      else
        Array(names_or_classes).each do |key|
          if key.is_a?(Module)
            @class_formatters[key] = formatter
          else
            @formatters[key.to_s] = formatter
          end
        end
      end
      self
    end

    # Remove formatters for specific tag names. The default formatter will still be applied.
    #
    # @param [String, Module, Array<String, Module>] names_or_classes The tag names or classes to remove the formatter from.
    # @return [Lumberjack::TagFormatter] self
    def remove(names_or_classes)
      Array(names_or_classes).each do |key|
        if key.is_a?(Module)
          @class_formatters.delete(key)
        else
          @formatters.delete(key.to_s)
        end
      end
      self
    end

    # Remove all formatters.
    #
    # @return [Lumberjack::TagFormatter] self
    def clear
      @default_formatter = nil
      @formatters.clear
      self
    end

    # Format a hash of tags using the formatters
    #
    # @param [Hash] tags The tags to format.
    # @return [Hash] The formatted tags.
    def format(tags)
      return nil if tags.nil?
      if @default_formatter.nil? && @formatters.empty? && @class_formatters.empty?
        return tags
      end

      formatted = {}
      tags.each do |name, value|
        formatter = @formatters[name.to_s] || class_formatter(value.class) || @default_formatter
        if formatter.is_a?(Lumberjack::Formatter)
          value = formatter.format(value)
        elsif formatter.respond_to?(:call)
          value = formatter.call(value)
        end
        formatted[name.to_s] = value
      end
      formatted
    end

    private

    def dereference_formatter(formatter)
      if formatter.is_a?(TaggedLoggerSupport::Formatter)
        formatter.__formatter
      elsif formatter.is_a?(Symbol)
        formatter_class_name = "#{formatter.to_s.gsub(/(^|_)([a-z])/) { |m| $~[2].upcase }}Formatter"
        Formatter.const_get(formatter_class_name).new
      else
        formatter
      end
    end

    def class_formatter(klass)
      formatter = @class_formatters[klass]
      return formatter if formatter

      formatters = @class_formatters.select { |k, _| klass <= k }
      return formatters.values.first if formatters.length <= 1

      superclass = klass.superclass
      while superclass
        formatter = formatters[superclass]
        return formatter if formatter
        superclass = superclass.superclass
      end

      formatters.values.first
    end
  end
end
