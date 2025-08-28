# frozen_string_literal: true

module Lumberjack
  # This class can be used as a return value from an AttributeFormatter to indicate that the
  # value should be remapped to a new attribute name.
  class RemapAttribute
    attr_reader :attributes

    # @param remapped_attributes [Hash] The remapped attribute with the new names.
    def initialize(remapped_attributes)
      @attributes = Lumberjack::Utils.flatten_attributes(remapped_attributes)
    end
  end
end
