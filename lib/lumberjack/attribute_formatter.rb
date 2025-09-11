# frozen_string_literal: true

module Lumberjack
  # AttributeFormatter provides flexible formatting control for log entry attributes (key-value pairs).
  # It allows you to specify different formatting rules for attribute names, object classes, or
  # provide a default formatter for all attributes.
  #
  # The formatter system works in a hierarchical manner:
  # 1. **Attribute-specific formatters** - Applied to specific attribute names (highest priority)
  # 2. **Class-specific formatters** - Applied based on the attribute value's class
  # 3. **Default formatter** - Applied to all other attributes (lowest priority)
  #
  # ## Key Features
  #
  # - **Nested attribute support**: Use dot notation (e.g., "user.email") to format nested hash values
  # - **Class-based formatting**: Apply formatters to all values of specific object types
  # - **Recursive processing**: Automatically handles nested hashes and arrays
  # - **Flexible formatter types**: Supports Formatter objects, callable objects, blocks, or symbols
  #
  # ## Formatter Types
  #
  # Formatters can be specified as:
  # - **Lumberjack::Formatter objects**: Full formatter instances with complex logic
  # - **Callable objects**: Any object responding to `#call(value)`
  # - **Blocks**: Inline formatting logic
  # - **Symbols**: References to predefined formatter classes (e.g., `:strip`, `:truncate`)
  #
  # @example Basic usage with build
  #   formatter = Lumberjack::AttributeFormatter.build do |config|
  #     config.add_attribute(["password", "secret", "token"]) { |value| "[REDACTED]" }
  #     config.add_attribute("user.email") { |email| email.downcase }
  #     config.add_class(Time, :date_time, "%Y-%m-%d %H:%M:%S")
  #   end
  #
  # ## Remapping attributes
  #
  # If the value returned by a formatter is a `Lumberjack::RemapAttributes` instance, then
  # the attributes will be remapped to the new attributes.
  #
  # @example
  #   formatter = Lumberjack::AttributeFormatter.new
  #   formatter.add_attribute("duration_ms") { |value| Lumberjack::RemapAttributes.new(duration: value.to_f / 1000) }
  #   formatter.format({ "duration_ms" => 1234 }) # => { "duration" => 1.234 }
  #
  # ## Remapping attributes
  #
  # If the value returned by a formatter is a `Lumberjack::RemapAttributes` instance, then
  # the attributes will be remapped to the new attributes.
  #
  # @example
  #   formatter = Lumberjack::AttributeFormatter.new
  #   formatter.add_attribute("user.email") { |email| email.downcase }
  #   formatter.add_attribute("config.database.password") { |pwd| "[HIDDEN]" }
  #
  # @see Lumberjack::Formatter
  # @see Lumberjack::EntryFormatter
  class AttributeFormatter
    class << self
      # Build a new attribute formatter using a configuration block. The block receives the
      # new formatter as a parameter, allowing you to configure it with methods like `add_attribute`,
      # `add_class`, `default`, etc.
      #
      # @yield [formatter] A block that configures the attribute formatter.
      # @return [Lumberjack::AttributeFormatter] A new configured attribute formatter.
      #
      # @example
      #   formatter = Lumberjack::AttributeFormatter.build do |config|
      #     config.default { |value| value.to_s.strip }
      #     config.add_attribute(["password", "secret"]) { |value| "[REDACTED]" }
      #     config.add_attribute("email") { |email| email.downcase }
      #     config.add_class(Time, :date_time, "%Y-%m-%d %H:%M:%S")
      #   end
      def build(&block)
        formatter = new
        block&.call(formatter)
        formatter
      end
    end

    # Create a new attribute formatter with no default formatters configured.
    # You'll need to add specific formatters using {#add_class}, {#add_attribute}, or {#default}.
    #
    # @return [Lumberjack::AttributeFormatter] A new empty attribute formatter.
    def initialize
      @attribute_formatter = {}
      @class_formatter = Formatter.new
      @default_formatter = nil
    end

    # Set a default formatter applied to all attribute values that don't have specific formatters.
    # This serves as the fallback formatting behavior for any attributes not covered by
    # attribute-specific or class-specific formatters.
    #
    # @param formatter [Lumberjack::Formatter, #call, Class, nil] The formatter to use.
    #   If nil, the block will be used as the formatter. If a class is passed, it will be
    #   instantiated with the args passed in.
    # @param args [Array] The arguments to pass to the constructor if formatter is a Class.
    # @yield [value] Block-based formatter that receives the attribute value.
    # @yieldparam value [Object] The attribute value to format.
    # @yieldreturn [Object] The formatted attribute value.
    # @return [Lumberjack::AttributeFormatter] Returns self for method chaining.
    def default(formatter = nil, *args, &block)
      formatter ||= block
      formatter = dereference_formatter(formatter, args)
      @default_formatter = formatter
      self
    end

    # Remove the default formatter. After calling this, attributes without specific formatters
    # will be passed through unchanged.
    #
    # @return [Lumberjack::AttributeFormatter] Returns self for method chaining.
    def remove_default
      @default_formatter = nil
      self
    end

    # Add formatters for specific attribute names or object classes. This is a convenience method
    # that automatically delegates to {#add_class} or {#add_attribute} based on the input type.
    #
    # When you pass a Module/Class, it creates a class-based formatter that applies to all
    # attribute values of that type. When you pass a String, it creates an attribute-specific
    # formatter for that exact attribute name.
    #
    # Class formatters are applied recursively to nested hashes and arrays, making them
    # powerful for formatting complex nested structures.
    #
    # @param names_or_classes [String, Module, Array<String, Module>] Attribute names or object classes.
    # @param formatter [Lumberjack::Formatter, #call, Symbol, nil] The formatter to use.
    # @yield [value] Block-based formatter that receives the attribute value.
    # @yieldparam value [Object] The attribute value to format.
    # @yieldreturn [Object] The formatted attribute value.
    # @return [Lumberjack::AttributeFormatter] Returns self for method chaining.
    # @deprecated Use {#add_class} or {#add_attribute} instead.
    def add(names_or_classes, formatter = nil, *args, &block)
      Utils.deprecated("AttributeFormatter#add", "AttributeFormatter#add is deprecated; use #add_class or #add_attribute instead.") do
        Array(names_or_classes).each do |obj|
          if obj.is_a?(Module)
            add_class(obj, formatter, *args, &block)
          else
            add_attribute(obj, formatter, *args, &block)
          end
        end
      end

      self
    end

    # Add formatters for specific object classes. The formatter will be applied to any attribute
    # value that is an instance of the registered class. This is particularly useful for formatting
    # all instances of specific data types consistently across your logs.
    #
    # Class formatters are recursive - they will be applied to matching objects found within
    # nested hashes and arrays.
    #
    # @param classes_or_names [String, Module, Array<String, Module>] Class names or modules.
    # @param formatter [Lumberjack::Formatter, #call, Symbol, Class, nil] The formatter to use.
    #   If a Class is provided, it will be instantiated with the provided args.
    # @param args [Array] The arguments to pass to the constructor if formatter is a Class.
    # @yield [value] Block-based formatter that receives the attribute value.
    # @yieldparam value [Object] The attribute value to format.
    # @yieldreturn [Object] The formatted attribute value.
    # @return [Lumberjack::AttributeFormatter] Returns self for method chaining.
    #
    # @example Time formatting
    #   formatter.add_class(Time, :date_time, "%Y-%m-%d %H:%M:%S")
    #   formatter.add_class([Date, DateTime]) { |dt| dt.strftime("%Y-%m-%d") }
    #
    # @example Security formatting
    #   formatter.add_class(SecretToken) { |token| "[TOKEN:#{token.id}]" }
    def add_class(classes_or_names, formatter = nil, *args, &block)
      formatter ||= block
      formatter = dereference_formatter(formatter, args)

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

    # Add formatters for specific attribute names. These formatters take precedence over
    # class formatters and the default formatter.
    #
    # Supports dot notation for nested attributes (e.g., "user.profile.email"). This allows
    # you to format specific values deep within nested hash structures.
    #
    # @param attribute_names [String, Symbol, Array<String, Symbol>] The attribute names to format.
    # @param formatter [Lumberjack::Formatter, #call, Symbol, nil] The formatter to use.
    # @yield [value] Block-based formatter that receives the attribute value.
    # @yieldparam value [Object] The attribute value to format.
    # @yieldreturn [Object] The formatted attribute value.
    # @return [Lumberjack::AttributeFormatter] Returns self for method chaining.
    #
    # @example Basic attribute formatting
    #   formatter.add_attribute("password") { |pwd| "[REDACTED]" }
    #   formatter.add_attribute("email") { |email| email.downcase }
    #
    # @example Nested attribute formatting
    #   formatter.add_attribute("user.profile.email") { |email| email.downcase }
    #   formatter.add_attribute("config.database.password") { "[HIDDEN]" }
    #
    # @example Multiple attributes
    #   formatter.add_attribute(["secret", "token", "api_key"]) { "[REDACTED]" }
    def add_attribute(attribute_names, formatter = nil, *args, &block)
      formatter ||= block
      formatter = dereference_formatter(formatter, args)

      Array(attribute_names).collect(&:to_s).each do |attribute_name|
        if formatter.nil?
          @attribute_formatter.delete(attribute_name)
        else
          @attribute_formatter[attribute_name] = formatter
        end
      end

      self
    end

    # Remove formatters for specific attribute names or classes. This reverts the specified
    # attributes or classes to use the default formatter (if configured) or no formatting.
    #
    # @param names_or_classes [String, Module, Array<String, Module>] Attribute names or classes
    #   to remove formatters for.
    # @return [Lumberjack::AttributeFormatter] Returns self for method chaining.
    # @deprecated Use {#remove_class} or {#remove_attribute} instead.
    def remove(names_or_classes)
      Utils.deprecated("AttributeFormatter#remove", "AttributeFormatter#remove is deprecated; use #remove_class or #remove_attribute instead.") do
        Array(names_or_classes).each do |key|
          if key.is_a?(Module)
            @class_formatter.remove(key)
          else
            @attribute_formatter.delete(key.to_s)
          end
        end
      end
      self
    end

    # Remove formatters for specific object classes. This reverts the specified classes
    # to use the default formatter (if configured) or no formatting.
    #
    # @param classes_or_names [String, Module, Array<String, Module>] The classes or names to remove.
    # @return [Lumberjack::AttributeFormatter] Returns self for method chaining.
    def remove_class(classes_or_names)
      Array(classes_or_names).each do |class_or_name|
        @class_formatter.remove(class_or_name)
      end
      self
    end

    # Remove formatters for specific attribute names. This reverts the specified attributes
    # to use the default formatter (if configured) or no formatting.
    #
    # @param attribute_names [String, Symbol, Array<String, Symbol>] The attribute names to remove.
    # @return [Lumberjack::AttributeFormatter] Returns self for method chaining.
    def remove_attribute(attribute_names)
      Array(attribute_names).collect(&:to_s).each do |attribute_name|
        @attribute_formatter.delete(attribute_name)
      end
      self
    end

    # Extend this formatter by merging the formats defined in the provided formatter into this one.
    #
    # @param formatter [Lumberjack::AttributeFormatter] The formatter to merge.
    # @return [self] Returns self for method chaining.
    def include(formatter)
      unless formatter.is_a?(Lumberjack::AttributeFormatter)
        raise ArgumentError.new("formatter must be a Lumberjack::AttributeFormatter")
      end

      @class_formatter.include(formatter.instance_variable_get(:@class_formatter))
      @attribute_formatter.merge!(formatter.instance_variable_get(:@attribute_formatter))

      default_formatter = formatter.instance_variable_get(:@default_formatter)
      @default_formatter = default_formatter if default_formatter

      self
    end

    # Extend this formatter by merging the formats defined in the provided formatter into this one.
    # Formats defined in this formatter will take precedence and not be overridden.
    #
    # @param formatter [Lumberjack::AttributeFormatter] The formatter to merge.
    # @return [self] Returns self for method chaining.
    def prepend(formatter)
      unless formatter.is_a?(Lumberjack::AttributeFormatter)
        raise ArgumentError.new("formatter must be a Lumberjack::AttributeFormatter")
      end

      @class_formatter.prepend(formatter.instance_variable_get(:@class_formatter))

      formatter.instance_variable_get(:@attribute_formatter).each do |key, value|
        @attribute_formatter[key] = value unless @attribute_formatter.include?(key)
      end

      @default_formatter ||= formatter.instance_variable_get(:@default_formatter)

      self
    end

    # Remove all configured formatters, including the default formatter. This resets the
    # formatter to a completely empty state where all attributes pass through unchanged.
    #
    # @return [Lumberjack::AttributeFormatter] Returns self for method chaining.
    def clear
      @default_formatter = nil
      @attribute_formatter.clear
      @class_formatter.clear
      self
    end

    # Check if the formatter has any configured formatters (attribute, class, or default).
    #
    # @return [Boolean] true if no formatters are configured, false otherwise.
    def empty?
      @attribute_formatter.empty? && @class_formatter.empty? && @default_formatter.nil?
    end

    # Format a hash of attributes using the configured formatters. This is the main
    # method that applies all formatting rules to transform attribute values.
    #
    # The formatting process follows this precedence:
    # 1. Attribute-specific formatters (highest priority)
    # 2. Class-specific formatters
    # 3. Default formatter (lowest priority)
    #
    # Nested hashes and arrays are processed recursively, and dot notation attribute
    # formatters are applied to nested structures.
    #
    # @param attributes [Hash, nil] The attributes hash to format.
    # @return [Hash, nil] The formatted attributes hash, or nil if input was nil.
    def format(attributes)
      return nil if attributes.nil?
      return attributes if empty?

      formated_attributes(attributes)
    end

    # Get the formatter for a specific class or attribute.
    #
    # @param class_or_attribute [String, Module] The class or attribute to get the formatter for.
    # @return [#call, nil] The formatter for the class or attribute, or nil if not found.
    def formatter_for(class_or_attribute)
      if class_or_attribute.is_a?(Module)
        formatter_for_class(class_or_attribute)
      else
        formatter_for_attribute(class_or_attribute)
      end
    end

    # Get the formatter for a specific class or class name.
    #
    # @param klass [String, Module] The class or class name to get the formatter for.
    # @return [#call, nil] The formatter for the class, or nil if not found.
    def formatter_for_class(klass)
      @class_formatter.formatter_for(klass)
    end

    # Get the formatter for a specific attribute.
    #
    # @param name [String, Symbol] The attribute name to get the formatter for.
    # @return [#call, nil] The formatter for the attribute, or nil if not found.
    def formatter_for_attribute(name)
      @attribute_formatter[name.to_s]
    end

    private

    # Recursively format all attributes in a hash, handling nested structures.
    #
    # @param attributes [Hash] The attributes to format.
    # @param skip_classes [Array<Class>, nil] Classes to skip during recursive formatting.
    # @param prefix [String, nil] Dot notation prefix for nested attribute names.
    # @return [Hash] The formatted attributes hash.
    def formated_attributes(attributes, skip_classes: nil, prefix: nil)
      formatted = {}

      attributes.each do |name, value|
        name = name.to_s
        value = formatted_attribute_value(name, value, skip_classes: skip_classes, prefix: prefix)
        if value.is_a?(RemapAttribute)
          formatted.merge!(value.attributes)
        else
          formatted[name] = value
        end
      end

      formatted
    end

    # Format a single attribute value using the appropriate formatter.
    #
    # @param name [String] The attribute name.
    # @param value [Object] The attribute value to format.
    # @param skip_classes [Array<Class>, nil] Classes to skip during recursive formatting.
    # @param prefix [String, nil] Dot notation prefix for nested attribute names.
    # @return [Object] The formatted attribute value.
    def formatted_attribute_value(name, value, skip_classes: nil, prefix: nil)
      prefixed_name = prefix ? "#{prefix}#{name}" : name
      using_class_formatter = false

      formatter = @attribute_formatter[prefixed_name]
      if formatter.nil? && (skip_classes.nil? || !skip_classes.include?(value.class))
        formatter = @class_formatter.formatter_for(value.class)
        using_class_formatter = true if formatter
      end

      formatter ||= @default_formatter

      formatted_value = begin
        if formatter.is_a?(Lumberjack::Formatter)
          formatter.format(value)
        elsif formatter.respond_to?(:call)
          formatter.call(value)
        else
          value
        end
      rescue SystemStackError, StandardError => e
        error_message = e.class.name
        error_message = "#{error_message} #{e.message}" if e.message && e.message != ""
        warn("<Error formatting #{value.class.name}: #{error_message}>")
        "<Error formatting #{value.class.name}: #{error_message}>"
      end

      if formatted_value.is_a?(MessageAttributes)
        formatted_value = formatted_value.attributes
      end

      if formatted_value.is_a?(Enumerable)
        skip_classes ||= []
        skip_classes << value.class if using_class_formatter
        sub_prefix = "#{prefixed_name}."

        formatted_value = if formatted_value.is_a?(Hash)
          formated_attributes(formatted_value, skip_classes: skip_classes, prefix: sub_prefix)
        else
          formatted_value.collect do |item|
            formatted_attribute_value(nil, item, skip_classes: skip_classes, prefix: sub_prefix)
          end
        end
      end

      formatted_value
    end

    # Convert symbol formatter references to actual formatter instances.
    #
    # @param formatter [Symbol, Class, #call] The formatter to dereference.
    # @param args [Array] The arguments to pass to the constructor if formatter is a Class.
    # @return [#call] The actual formatter instance.
    def dereference_formatter(formatter, args)
      if formatter.is_a?(Symbol)
        FormatterRegistry.formatter(formatter, *args)
      else
        formatter
      end
    end
  end
end
