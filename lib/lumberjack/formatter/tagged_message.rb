# frozen_string_literal: true

require_relative "../message_attributes"

module Lumberjack
  # This is a deprecated alias for Lumberjack::MessageAttributes.
  #
  # @see MessageAttributes
  class Formatter::TaggedMessage < MessageAttributes
    def initialize(message, attributes)
      Utils.deprecated("Lumberjack::Formatter::TaggedMessage", "Use Lumberjack::MessageAttributes instead.") do
        super
      end
    end
  end
end
