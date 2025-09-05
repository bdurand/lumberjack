# frozen_string_literal: true

module Lumberjack
  class Formatter
    # Format an object by calling `to_s` on it. This is the simplest formatter
    # implementation and is commonly used as a fallback for objects that don't
    # have specialized formatters.
    class StringFormatter
      FormatterRegistry.add(:string, self)

      # Convert an object to its string representation.
      #
      # @param obj [Object] The object to format.
      # @return [String] The string representation of the object.
      def call(obj)
        obj.to_s
      end
    end
  end
end
