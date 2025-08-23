# frozen_string_literal: true

module Lumberjack
  class Formatter
    # Round numeric values to a set number of decimal places. This is useful when logging
    # floating point numbers to reduce noise and rounding errors in the logs.
    #
    # The formatter only affects numeric values, leaving other object types unchanged.
    # This makes it safe to use as a general-purpose formatter for attributes that
    # might contain various data types.
    class RoundFormatter
      # @param precision [Integer] The number of decimal places to round to (defaults to 3).
      def initialize(precision = 3)
        @precision = precision
      end

      # Round a numeric value to the configured precision.
      #
      # @param obj [Object] The object to format. Only numeric values are rounded.
      # @return [Numeric, Object] The rounded number if the object is numeric,
      #   otherwise returns the object unchanged.
      def call(obj)
        if obj.is_a?(Numeric)
          obj.round(@precision)
        else
          obj
        end
      end
    end
  end
end
