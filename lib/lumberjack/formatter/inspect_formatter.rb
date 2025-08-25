# frozen_string_literal: true

module Lumberjack
  class Formatter
    # Format an object by calling `inspect` on it. This formatter provides
    # a debugging-friendly representation of objects, showing their internal
    # structure and contents in a readable format.
    #
    # The InspectFormatter is particularly useful for logging complex objects
    # where you need to see their complete state, such as arrays, hashes,
    # or custom objects. It relies on Ruby's built-in `inspect` method,
    # which provides detailed object representations.
    class InspectFormatter
      # Convert an object to its inspect representation.
      #
      # @param obj [Object] The object to format.
      # @return [String] The inspect representation of the object.
      def call(obj)
        obj.inspect
      end
    end
  end
end
