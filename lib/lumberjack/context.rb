# frozen_string_literal: true

module Lumberjack
  # A context is used to store values used in logging that can be made local to a block.
  class Context
    attr_reader :attributes
    attr_reader :level
    attr_reader :progname
    attr_reader :default_severity

    # @param parent_context [Context] A parent context to inherit from.
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

    def level=(value)
      value = Severity.coerce(value) unless value.nil?
      @level = value
    end

    def progname=(value)
      @progname = value&.to_s&.freeze
    end

    # Set attributes on the context.
    #
    # @param attributes [Hash] The attributes to set.
    # @return [void]
    def assign_attributes(attributes)
      attributes_helper.update(attributes)
    end

    # Get a context attribute.
    #
    # @param key [String, Symbol] The attribute key.
    # @return [Object] The attribute value.
    def [](key)
      attributes_helper[key]
    end

    # Set a context attribute.
    #
    # @param key [String, Symbol] The attribute name.
    # @param value [Object] The attribute value.
    # @return [void]
    def []=(key, value)
      attributes_helper[key] = value
    end

    # Remove all attributes from the context.
    def clear_attributes
      @attributes&.clear
    end

    # Remove attributes from the context.
    #
    # @param keys [Array<String, Symbol>] The attribute keys to remove.
    # @return [void]
    def delete(*keys)
      attributes_helper.delete(*keys)
    end

    def default_severity=(value)
      value = Severity.coerce(value) unless value.nil?
      @default_severity = value
    end

    # Clear all the context data.
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
      TagContext.new(@attributes)
    end
  end
end
