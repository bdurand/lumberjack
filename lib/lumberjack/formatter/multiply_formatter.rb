# frozen_string_literal: true

module Lumberjack
  class Formatter
    # This formatter can be used to multiply a numeric value by a specified multiplier and
    # optionally round to a specified number of decimal places.
    #
    # This is useful for unit conversions (e.g., converting seconds to milliseconds)
    # or scaling values for display purposes. Non-numeric values are passed through unchanged.
    class MultiplyFormatter
      FormatterRegistry.add(:multiply, self)

      # @param multiplier [Numeric] The multiplier to apply to the value.
      # @param decimals [Integer, nil] The number of decimal places to round the result to.
      #   If nil, no rounding is applied.
      def initialize(multiplier, decimals = nil)
        @multiplier = multiplier
        @decimals = decimals
      end

      # Multiply a numeric value by the configured multiplier and optionally round.
      #
      # @param value [Object] The value to format. Only numeric values are processed.
      # @return [Numeric, Object] The multiplied (and optionally rounded) value if numeric,
      #   otherwise returns the original value unchanged.
      def call(value)
        return value unless value.is_a?(Numeric)

        value *= @multiplier
        value = value.round(@decimals) if @decimals
        value
      end
    end
  end
end
