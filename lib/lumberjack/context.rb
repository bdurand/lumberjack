# frozen_string_literal: true

module Lumberjack
  # A context is used to store tags that are then added to all log entries within a block.
  class Context
    attr_reader :tags
    attr_reader :level
    attr_reader :progname

    # @param parent_context [Context] A parent context to inherit tags from.
    def initialize(parent_context = nil)
      @tags = nil
      @level = nil
      @progname = nil

      if parent_context
        @tags = parent_context.tags.dup if parent_context.tags
        self.level = parent_context.level
        self.progname = parent_context.progname
      end
    end

    def level=(value)
      value = Lumberjack::Severity.coerce(value) unless value.nil?
      @level = value
    end

    def progname=(value)
      @progname = value&.to_s&.freeze
    end

    # Set tags on the context.
    #
    # @param tags [Hash] The tags to set.
    # @return [void]
    def tag(tags)
      tag_context.tag(tags)
    end

    # Get a context tag.
    #
    # @param key [String, Symbol] The tag key.
    # @return [Object] The tag value.
    def [](key)
      tag_context[key]
    end

    # Set a context tag.
    #
    # @param key [String, Symbol] The tag key.
    # @param value [Object] The tag value.
    # @return [void]
    def []=(key, value)
      tag_context[key] = value
    end

    # Remove all tags from the context.
    def clear_tags
      @tags&.clear
    end

    # Remove tags from the context.
    #
    # @param keys [Array<String, Symbol>] The tag keys to remove.
    # @return [void]
    def delete(*keys)
      tag_context.delete(*keys)
    end

    # Clear all the context data.
    #
    # @return [void]
    def reset
      @tags&.clear
      @level = nil
      @progname = nil
    end

    private

    def tag_context
      @tags ||= {}
      TagContext.new(@tags)
    end
  end
end
