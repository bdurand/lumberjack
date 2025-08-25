# frozen_string_literal: true

module Lumberjack
  class Formatter
    # No-op formatter that returns the object unchanged. This formatter is useful
    # as a default or fallback formatter when you want to preserve the original
    # object without any transformation.
    #
    # The ObjectFormatter is commonly used in scenarios where you want to maintain
    # the original data structure and let downstream components handle the actual
    # formatting, or when you need a placeholder formatter in the formatter chain.
    class ObjectFormatter
      # Return the object unchanged.
      #
      # @param obj [Object] The object to format.
      # @return [Object] The original object without any modifications.
      def call(obj)
        obj
      end
    end
  end
end
