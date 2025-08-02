# frozen_string_literal: true

module Lumberjack
  # A tag context provides an interface for manipulating a tag hash.
  class TagContext
    def initialize(tags)
      @tags = tags
    end

    # Merge new tags into the context tags. Tag values will be flattened using dot notation
    # on the keys. So `{ a: { b: 'c' } }` will become `{ 'a.b' => 'c' }`.
    #
    # If a block is given, then the tags will only be added for the duration of the block.
    #
    # @param tags [Hash] The tags to set.
    # @return [void]
    def tag(tags)
      @tags.merge!(Utils.flatten_tags(tags))
    end

    # Get a tag value.
    #
    # @param name [String, Symbol] The tag key.
    # @return [Object] The tag value.
    def [](name)
      return nil if @tags.empty?

      name = name.to_s
      return @tags[name] if @tags.include?(name)

      # Check for partial matches in dot notation and return the hash representing the partial match.
      partial_match_tags = {}
      @tags.keys.select { |key| key.include?(".") }.each do |key|
        parts = key.split(".")
        while (subkey = parts.pop)
          partial_match_tags[parts.join(".")] = {subkey => @tags[key]}
        end
      end
      partial_match_tags[name]
    end

    # Set a context tag.
    #
    # @param name [String, Symbol] The tag name.
    # @param value [Object] The tag value.
    # @return [void]
    def []=(name, value)
      if value.is_a?(Hash)
        @tags.merge!(Utils.flatten_tags(name => value))
      else
        @tags[name.to_s] = value
      end
    end

    # Remove tags from the context.
    #
    # @param names [Array<String, Symbol>] The tag names to remove.
    # @return [void]
    def delete(*names)
      names.each do |name|
        prefix_key = "#{name}."
        @tags.delete_if { |k, _| k == name.to_s || k.start_with?(prefix_key) }
      end
      nil
    end

    # Return a copy of the tags as a hash.
    #
    # @return [Hash]
    def to_h
      @tags.dup
    end
  end
end
