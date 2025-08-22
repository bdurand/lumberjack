# frozen_string_literal: true

module Lumberjack
  class Device
    # A logging device that discards all output. This device provides a silent
    # logging implementation useful for testing environments, performance benchmarks,
    # or production scenarios where logging needs to be temporarily disabled without
    # changing logger configuration.
    #
    # The Null device implements the complete Device interface but performs no
    # actual operations, making it both efficient and transparent. It accepts
    # any constructor arguments for compatibility but ignores them all.
    #
    # @example Creating a silent logger
    #   logger = Lumberjack::Logger.new(Lumberjack::Device::Null.new)
    #   logger.info("This message is discarded")
    #
    # @example Using the convenience constructor
    #   logger = Lumberjack::Logger.new(:null)
    #   logger.error("This error is also discarded")
    class Null < Device
      def initialize(*args)
      end

      # Discard the log entry without performing any operation.
      #
      # @param entry [Lumberjack::LogEntry] The log entry to discard.
      # @return [void]
      def write(entry)
      end
    end
  end
end
