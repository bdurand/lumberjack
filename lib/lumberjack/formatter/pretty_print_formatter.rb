# frozen_string_literal: true

require "pp"
require "stringio"

module Lumberjack
  class Formatter
    # Format an object with its pretty print method. This formatter provides multi-line,
    # indented output that makes complex data structures easier to read and debug.
    # It's particularly useful for logging hashes, arrays, and other nested objects.
    #
    # The formatter uses Ruby's built-in PP (Pretty Print) library to generate
    # well-formatted output with appropriate indentation and line breaks.
    class PrettyPrintFormatter
      FormatterRegistry.add(:pretty_print, self)

      # @!attribute [rw] width
      #   @return [Integer] The maximum width of the message.
      attr_accessor :width

      # Create a new formatter. The maximum width of the message can be specified with the width
      # parameter (defaults to 79 characters).
      #
      # @param width [Integer] The maximum width of the message.
      def initialize(width = 79)
        @width = width
      end

      # Format an object using pretty print with the configured width.
      #
      # @param obj [Object] The object to format.
      # @return [String] The pretty-printed representation of the object.
      def call(obj)
        s = StringIO.new
        PP.pp(obj, s)
        s.string.chomp
      end
    end
  end
end
