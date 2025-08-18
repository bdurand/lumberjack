# frozen_string_literal: true

module Lumberjack
  # A attribute context provides an interface for manipulating a attribute hash.
  class TagContext
    def initialize(attributes)
      @attributes = attributes
    end

    # Merge new attributes into the context attributes. Tag values will be flattened using dot notation
    # on the keys. So `{ a: { b: 'c' } }` will become `{ 'a.b' => 'c' }`.
    #
    # If a block is given, then the attributes will only be added for the duration of the block.
    #
    # @param attributes [Hash] The attributes to set.
    # @return [void]
    def update(attributes)
      @attributes.merge!(Utils.flatten_attributes(attributes))
    end

    def tag(tags)
      update(tags)
    end

    # Get a attribute value.
    #
    # @param name [String, Symbol] The attribute key.
    # @return [Object] The attribute value.
    def [](name)
      return nil if @attributes.empty?

      name = name.to_s
      return @attributes[name] if @attributes.include?(name)

      # Check for partial matches in dot notation and return the hash representing the partial match.
      prefix_key = "#{name}."
      matching_attributes = {}
      @attributes.each do |key, value|
        if key.start_with?(prefix_key)
          # Remove the prefix to get the relative key
          relative_key = key[prefix_key.length..]
          matching_attributes[relative_key] = value
        end
      end

      return nil if matching_attributes.empty?
      matching_attributes
    end

    # Set a attribute value.
    #
    # @param name [String, Symbol] The attribute name.
    # @param value [Object] The attribute value.
    # @return [void]
    def []=(name, value)
      if value.is_a?(Hash)
        @attributes.merge!(Utils.flatten_attributes(name => value))
      else
        @attributes[name.to_s] = value
      end
    end

    # Remove attributes from the context.
    #
    # @param names [Array<String, Symbol>] The attribute names to remove.
    # @return [void]
    def delete(*names)
      names.each do |name|
        prefix_key = "#{name}."
        @attributes.delete_if { |k, _| k == name.to_s || k.start_with?(prefix_key) }
      end
      nil
    end

    # Return a copy of the attributes as a hash.
    #
    # @return [Hash]
    def to_h
      @attributes.dup
    end
  end
end
