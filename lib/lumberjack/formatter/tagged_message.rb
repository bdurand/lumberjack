# frozen_string_literal: true

module Lumberjack
  class Formatter
    # This class can be used as the return value from a formatter `call` method to
    # extract additional attributes from an object being logged. This can be useful when there
    # using structured logging to include important metadata in the log message.
    #
    # @example
    #  # Automatically add attributes with error details when logging an exception.
    #  logger.add_formatter(Exception, ->(e) {
    #    Lumberjack::Formatter::TaggedMessage.new(e.message, {
    #      error: {
    #        message: e.message,
    #        class: e.class.name,
    #        trace: e.backtrace
    #      }
    #    })
    #  })
    class TaggedMessage
      attr_reader :message, :attributes

      # @param [Formatter] formatter The formatter to apply the transformation to.
      # @param [Proc] transform The transformation function to apply to the formatted string.
      def initialize(message, attributes)
        @message = message
        @attributes = attributes || {}
      end

      def to_s
        inspect
      end

      def inspect
        {message: @message, attributes: @attributes}.inspect
      end
    end
  end
end
