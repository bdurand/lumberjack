# frozen_string_literal: true

module Lumberjack
  # Class for formatting attributes. You can register a default formatter and tag
  # name specific formatters. Formatters can be either `Lumberjack::Formatter`
  # objects or any object that responds to `call`.
  #
  # @example
  #   attribute_formatter = Lumberjack::TagFormatter.new.default(Lumberjack::Formatter.new)
  #   attribute_formatter.add(["password", "email"]) { |value| "***" }
  #   attribute_formatter.add("finished_at", Lumberjack::Formatter::DateTimeFormatter.new("%Y-%m-%dT%H:%m:%S%z"))
  #   attribute_formatter.add(Enumerable) { |value| value.join(", ") }
  class TagFormatter
    def initialize
      @attribute_formatters = {}
      @class_formatter = Formatter.empty
      @default_formatter = nil
    end

    # Add a default formatter applied to all tag values. This can either be a Lumberjack::Formatter
    # or an object that responds to `call` or a block.
    #
    # @param formatter [Lumberjack::Formatter, #call, nil] The formatter to use.
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

    # Add a formatter for specific tag names or object classes. This is a convenience method and will call
    # either `add_class` or `add_tag_name` as appropriate.
    #
    # Class formatters will be applied recursively to nested hashes and arrays.
    #
    # @param names_or_classes [String, Module, Array<String, Module>] The tag names or object classes
    #   to apply the formatter to.
    # @param formatter [Lumberjack::Formatter, #call, nil] The formatter to use.
    #    If this is nil, then the block will be used as the formatter.
    # @return [Lumberjack::TagFormatter] self
    #
    # @example
    #  attribute_formatter.add("password", &:redact)
    def add(names_or_classes, formatter = nil, &block)
      Array(names_or_classes).each do |obj|
        if obj.is_a?(Module)
          add_class(obj, formatter, &block)
        else
          add_tag(obj, formatter, &block)
        end
      end

      self
    end

    # Add a formatter for specific object classes. This can either be a Lumberjack::Formatter
    # or an object that responds to `call` or a block. The formatter will be applied if the tag value
    # is an instance of a registered class.
    #
    # @param classes_or_names [String, Module, Array<String, Module>] The class names or modules
    #   to apply the formatter to.
    # @param formatter [Lumberjack::Formatter, #call, nil] The formatter to use.
    #    If this is nil, then the block will be used as the formatter.
    # @return [Lumberjack::TagFormatter] self
    def add_class(classes_or_names, formatter = nil, &block)
      formatter ||= block
      formatter = dereference_formatter(formatter)

      Array(classes_or_names).each do |class_or_name|
        class_name = class_or_name.to_s
        if formatter.nil?
          @class_formatter.remove(class_name)
        else
          @class_formatter.add(class_name, formatter)
        end
      end

      self
    end

    # Add a formatter for specific tag names. Tag formatters can be applied to nested hashes using dot syntax.
    # For example, if you add a formatter for "foo.bar", it will be applied to the value of the "bar" key in
    # the "foo" tag if that value is a hash.
    #
    # Tag formatters will take precedence over class formatters.
    #
    # @param tag_names [String, Module, Array<String, Module>] The tag names to apply the formatter to.
    # @param formatter [Lumberjack::Formatter, #call, nil] The formatter to use.
    #    If this is nil, then the block will be used as the formatter.
    # @return [Lumberjack::TagFormatter] self
    def add_tag(tag_names, formatter = nil, &block)
      formatter ||= block
      formatter = dereference_formatter(formatter)

      Array(tag_names).each do |tag_name|
        tag_name = tag_name.to_s
        if formatter.nil?
          @attribute_formatters.delete(tag_name)
        else
          @attribute_formatters[tag_name] = formatter
        end
      end

      self
    end

    # Remove formatters for specific tag names. The default formatter will still be applied.
    #
    # @param names_or_classes [String, Module, Array<String, Module>] The tag names or classes to remove the formatter from.
    # @return [Lumberjack::TagFormatter] self
    def remove(names_or_classes)
      Array(names_or_classes).each do |key|
        if key.is_a?(Module)
          @class_formatter.remove(key)
        else
          @attribute_formatters.delete(key.to_s)
        end
      end
      self
    end

    # Remove all formatters.
    #
    # @return [Lumberjack::TagFormatter] self
    def clear
      @default_formatter = nil
      @attribute_formatters.clear
      @class_formatter.clear
      self
    end

    def empty?
      @attribute_formatters.empty? && @class_formatter.empty? && @default_formatter.nil?
    end

    # Format a hash of attributes using the formatters
    #
    # @param attributes [Hash] The attributes to format.
    # @return [Hash] The formatted attributes.
    def format(attributes)
      return nil if attributes.nil?
      return attributes if empty?

      formated_attributes(attributes)
    end

    private

    def formated_attributes(attributes, skip_classes: nil, prefix: nil)
      formatted = {}

      attributes.each do |name, value|
        name = name.to_s
        formatted[name] = formatted_tag_value(name, value, skip_classes: skip_classes, prefix: prefix)
      end

      formatted
    end

    def formatted_tag_value(name, value, skip_classes: nil, prefix: nil)
      prefixed_name = prefix ? "#{prefix}#{name}" : name
      using_class_formatter = false

      formatter = @attribute_formatters[prefixed_name]
      if formatter.nil? && (skip_classes.nil? || !skip_classes.include?(value.class))
        formatter = @class_formatter.formatter_for(value.class)
        using_class_formatter = true if formatter
      end

      formatter ||= @default_formatter

      formatted_value = if formatter.is_a?(Lumberjack::Formatter)
        formatter.format(value)
      elsif formatter.respond_to?(:call)
        formatter.call(value)
      else
        value
      end

      if formatted_value.is_a?(Enumerable)
        skip_classes ||= []
        skip_classes << value.class if using_class_formatter
        sub_prefix = "#{prefixed_name}."

        formatted_value = if formatted_value.is_a?(Hash)
          formated_attributes(formatted_value, skip_classes: skip_classes, prefix: sub_prefix)
        else
          formatted_value.collect do |item|
            formatted_tag_value(nil, item, skip_classes: skip_classes, prefix: sub_prefix)
          end
        end
      end

      formatted_value
    end

    def dereference_formatter(formatter)
      if formatter.is_a?(Symbol)
        formatter_class_name = "#{formatter.to_s.gsub(/(^|_)([a-z])/) { |m| $~[2].upcase }}Formatter"
        Formatter.const_get(formatter_class_name).new
      else
        formatter
      end
    end
  end
end
