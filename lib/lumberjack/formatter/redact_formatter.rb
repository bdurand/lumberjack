# frozen_string_literal: true

module Lumberjack
  class Formatter
    # Log sensitive information in a redacted format showing the first and last
    # characters of the value, with the rest replaced by asterisks. The number of
    # characters shown is dependent on the length of the value; short values will
    # not show any characters in order to avoid revealing too much information.
    #
    # This formatter is useful for logging sensitive data while still providing
    # enough context to distinguish between different values during debugging.
    class RedactFormatter
      # Redact a string value by showing only the first and last characters.
      #
      # @param obj [Object] The object to format. Only strings are redacted.
      # @return [String, Object] The redacted string if the object is a string,
      #   otherwise returns the object unchanged.
      #
      # @example Different string lengths
      #   formatter.call("password123")     # => "pa*******23"
      #   formatter.call("secret")          # => "s****t"
      #   formatter.call("abc")             # => "*****"
      def call(obj)
        return obj unless obj.is_a?(String)

        if obj.length > 8
          "#{obj[0..1]}#{"*" * (obj.length - 4)}#{obj[-2..]}"
        elsif obj.length > 5
          "#{obj[0]}#{"*" * (obj.length - 2)}#{obj[-1]}"
        else
          "*****"
        end
      end
    end
  end
end
