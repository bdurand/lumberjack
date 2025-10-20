# frozen_string_literal: true

module Lumberjack
  # This class can be used as the return value from a formatter +call+ method to
  # extract additional attributes from an object being logged. This can be useful when there
  # using structured logging to include important metadata in the log entry in addition
  # to the message.
  #
  # @example
  #  # Automatically add attributes with error details when logging an exception.
  #  logger.add_formatter(Exception, ->(e) {
  #    Lumberjack::MessageAttributes.new(e.inspect, {
  #      error: {
  #        message: e.message,
  #        class: e.class.name,
  #        stack: e.backtrace
  #      }
  #    })
  #  })
  class MessageAttributes
    attr_reader :message, :attributes

    # @param message [Object] The message to be logged.
    # @param attributes [Hash] The attributes to be associated with the message.
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
