# frozen_string_literal: true

module Lumberjack
  class Formatter
    # Format an object by calling +to_s+ on it and stripping leading and trailing whitespace.
    # This formatter is useful for cleaning up string values that may have unwanted whitespace
    # from user input, file processing, or other sources.
    #
    # The StripFormatter combines string conversion with whitespace normalization,
    # making it ideal for attribute values that should be clean and consistent
    # in log output.
    class StripFormatter
      FormatterRegistry.add(:strip, self)

      # Convert an object to a string and remove leading and trailing whitespace.
      #
      # @param obj [Object] The object to format.
      # @return [String] The string representation with whitespace stripped.
      def call(obj)
        obj.to_s.strip
      end
    end
  end
end
