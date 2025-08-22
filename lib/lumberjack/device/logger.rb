# frozen_string_literal: true

module Lumberjack
  # Device that writes log entries to a Lumberjack logger. You can use
  # this in combination with the Lumberjack::Device::Multi device to
  # create a master logger that broadcasts to other loggers.
  class Device::Logger < Device
    attr_reader :logger

    def initialize(logger)
      raise ArgumentError.new("Logger must be a Lumberjack logger") unless logger.is_a?(Lumberjack::ContextLogger)

      @logger = logger
    end

    def write(entry)
      @logger.add_entry(entry.severity, entry.message, entry.progname, entry.attributes)
    end
  end
end
