# frozen_string_literal: true

module Lumberjack
  # Context stores logging settings and attributes that can be scoped to specific code blocks
  # or inherited between loggers. It provides a hierarchical system for managing logging state
  # including level, progname, default severity, and custom attributes.
  #
  # Child contexts inherit all configuration from their parent but can override any values.
  # Changes to child contexts don't affect parent contexts, providing true isolation.
  #
  # @see Lumberjack::ContextLogger
  # @see Lumberjack::AttributesHelper
  class Context
    # The attributes hash containing key-value pairs to include in log entries.
    # @return [Hash, nil] The attributes hash, or nil if no attributes are set.
    attr_reader :attributes

    # The logging level for this context.
    # @return [Integer, nil] The logging level, or nil if not set (inherits from parent or default).
    attr_reader :level

    # The program name for this context.
    # @return [String, nil] The program name, or nil if not set (inherits from parent or default).
    attr_reader :progname

    # The default severity used when writing log messages directly to a stream.
    # @return [Integer, nil] The default severity level, or nil if not set.
    attr_reader :default_severity

    # The parent context from which this context inherited its initial attributes.
    # @return [Lumberjack::Context, nil] The parent context, or nil if this is a top-level context.
    # @api private
    attr_accessor :parent

    # Create a new context, optionally inheriting configuration from a parent context.
    #
    # When a parent context is provided, the new context inherits all configuration
    # (level, progname, default_severity) and a copy of all attributes. Changes to the
    # new context won't affect the parent context, providing true isolation.
    #
    # @param parent_context [Lumberjack::Context, nil] The parent context to inherit from.
    def initialize(parent_context = nil)
      @attributes = nil
      @level = nil
      @progname = nil
      @default_severity = nil

      if parent_context
        @attributes = parent_context.attributes.dup if parent_context.attributes
        self.level = parent_context.level
        self.progname = parent_context.progname
      end
    end

    # Set the logging level for this context. The level determines which log entries
    # will be processed when this context is active.
    #
    # @param value [Integer, Symbol, String, nil] The logging level. Can be a numeric level,
    #   symbol (:debug, :info, :warn, :error, :fatal), string, or nil to unset.
    # @return [void]
    def level=(value)
      value = Severity.coerce(value) unless value.nil?
      @level = value
    end

    # Set the program name for this context. The progname identifies the component
    # or program that is generating log entries.
    #
    # @param value [String, Symbol, nil] The program name. Will be converted to a frozen string.
    # @return [void]
    def progname=(value)
      @progname = value&.to_s&.freeze
    end

    # Assign multiple attributes to this context from a hash. This method allows
    # bulk assignment of context attributes and supports nested attribute names
    # using dot notation.
    #
    # @param attributes [Hash] A hash of attribute names to values. Keys can be strings
    #   or symbols, and support dot notation for nested attributes.
    # @return [void]
    # @see #[]= for setting individual attributes
    def assign_attributes(attributes)
      attributes_helper.update(attributes)
    end

    # Get a context attribute by key. Supports both string and symbol keys,
    # and can access nested attributes using dot notation.
    #
    # @param key [String, Symbol] The attribute key. Supports dot notation for nested access.
    # @return [Object] The attribute value, or nil if the key doesn't exist.
    def [](key)
      attributes_helper[key]
    end

    # Set a context attribute by key. Supports both string and symbol keys,
    # and can set nested attributes using dot notation.
    #
    # @param key [String, Symbol] The attribute key. Supports dot notation for nested assignment.
    # @param value [Object] The attribute value to set.
    # @return [void]
    def []=(key, value)
      attributes_helper[key] = value
    end

    # Remove all attributes from this context. This only affects attributes
    # directly set on this context, not those inherited from parent contexts.
    def clear_attributes
      @attributes&.clear
    end

    # Remove specific attributes from this context. This only affects attributes
    # directly set on this context, not those inherited from parent contexts.
    # Supports dot notation for nested attribute removal.
    #
    # @param keys [Array<String, Symbol>] The attribute keys to remove. Can use
    #   dot notation for nested attributes.
    # @return [void]
    def delete(*keys)
      attributes_helper.delete(*keys)
    end

    # Set the default severity level for this context. This determines the minimum
    # severity level for log entries when no explicit level is specified.
    #
    # @param value [Integer, Symbol, String, nil] The default severity level. Can be a numeric level,
    #   symbol (:debug, :info, :warn, :error, :fatal), string, or nil to unset.
    # @return [void]
    def default_severity=(value)
      value = Severity.coerce(value) unless value.nil?
      @default_severity = value
    end

    # Clear all context data including attributes, level, and progname.
    # This resets the context to its initial state while preserving the
    # parent context relationship.
    #
    # @return [void]
    def reset
      @attributes&.clear
      @level = nil
      @progname = nil
    end

    private

    def attributes_helper
      @attributes ||= {}
      AttributesHelper.new(@attributes)
    end
  end
end
