# frozen_string_literal: true

module Lumberjack
  # This class can be used as a return value from an AttributeFormatter to indicate that the
  # value should be remapped to a new attribute name.
  #
  # @example
  #   # Transform duration_millis and duration_micros to seconds and move to
  #   # the duration attribute.
  #   logger.attribute_formatter.add_attribute("duration_ms") do |value|
  #     Lumberjack::RemapAttribute.new("duration" => value.to_f / 1000)
  #   end
  #   logger.attribute_formatter.add_attribute("duration_micros") do |value|
  #     Lumberjack::RemapAttribute.new("duration" => value.to_f / 1_000_000)
  #   end
  class RemapAttribute
    attr_reader :attributes

    # @param remapped_attributes [Hash] The remapped attribute with the new names.
    def initialize(remapped_attributes)
      @attributes = Lumberjack::Utils.flatten_attributes(remapped_attributes)
    end
  end
end
