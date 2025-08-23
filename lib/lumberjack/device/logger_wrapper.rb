# frozen_string_literal: true

module Lumberjack
  # A logging device that forwards log entries to another Lumberjack logger instance.
  # This device enables hierarchical logging architectures and broadcasting scenarios
  # where log entries need to be distributed to multiple loggers or processed through
  # different logging pipelines.
  #
  # The device is particularly useful when combined with Device::Multi to create
  # master loggers that can simultaneously write to multiple destinations (files,
  # databases, external services) while maintaining consistent formatting and
  # attribute handling across all targets.
  #
  # Unlike other devices that write directly to output streams, this device delegates
  # to another logger's processing pipeline, allowing for complex logging topologies
  # and reuse of existing logger configurations.
  #
  # @example Basic logger forwarding
  #   file_logger = Lumberjack::Logger.new("/var/log/app.log")
  #   logger_device = Lumberjack::Device::LoggerWrapper.new(file_logger)
  #
  # @example Broadcasting with Multi device
  #   main_logger = Lumberjack::Logger.new("/var/log/main.log")
  #   error_logger = Lumberjack::Logger.new("/var/log/errors.log")
  #
  #   broadcast_device = Lumberjack::Device::Multi.new([
  #     Lumberjack::Device::LoggerWrapper.new(main_logger),
  #     Lumberjack::Device::LoggerWrapper.new(error_logger)
  #   ])
  #
  #   master_logger = Lumberjack::Logger.new(broadcast_device)
  #
  # @example Hierarchical logging with filtering
  #   # Main application logger
  #   app_logger = Lumberjack::Logger.new("/var/log/app.log")
  #
  #   # Focused error logs
  #   error_logger = Lumberjack::Logger.new("/var/log/error.log")
  #   error_logger.level = Logger::WARN
  #
  #   # Route all logs to app, error logs to error logger
  #   multi_device = Lumberjack::Device::Multi.new([
  #     Lumberjack::Device::LoggerWrapper.new(app_logger),
  #     Lumberjack::Device::LoggerWrapper.new(error_logger)
  #   ])
  #
  # @see Device::Multi
  # @see Lumberjack::Logger
  # @see Lumberjack::ContextLogger
  class Device::LoggerWrapper < Device
    # @!attribute [r] logger
    #   @return [Lumberjack::ContextLogger] The target logger that will receive forwarded log entries
    attr_reader :logger

    # Initialize a new Logger device that forwards entries to the specified logger.
    # The target logger must be a Lumberjack logger that supports the ContextLogger
    # interface to ensure proper entry handling and attribute processing.
    #
    # @param logger [Lumberjack::ContextLogger] The target logger to receive forwarded entries.
    #   Must be a Lumberjack logger instance (Logger, ForkedLogger, etc.) that includes
    #   the ContextLogger mixin for proper entry processing.
    #
    # @raise [ArgumentError] If the provided logger is not a Lumberjack::ContextLogger
    def initialize(logger)
      raise ArgumentError.new("Logger must be a Lumberjack logger") unless logger.is_a?(Lumberjack::ContextLogger)

      @logger = logger
    end

    # Forward a log entry to the target logger for processing. This method extracts
    # the entry components and delegates to the target logger's add_entry method,
    # ensuring that all attributes, formatting, and processing logic of the target
    # logger are properly applied.
    #
    # The forwarded entry maintains all original metadata including severity,
    # timestamp, program name, and custom attributes, allowing the target logger
    # to process it as if it were generated directly.
    #
    # @param entry [Lumberjack::LogEntry] The log entry to forward to the target logger
    # @return [void]
    def write(entry)
      @logger.add_entry(entry.severity, entry.message, entry.progname, entry.attributes)
    end

    # Closes the target logger to release any resources or finalize log output.
    # This method delegates to the target logger's `close` method.
    #
    # @return [void]
    def close
      @logger.close
    end

    # Reopen the underlying logger device. This is typically used to reopen log files
    # after log rotation or to refresh the logger's output stream.
    #
    # Delegates to the target logger's `reopen` method.
    #
    # @return [void]
    def reopen
      @logger.reopen
    end

    # Flushes the target logger, ensuring that any buffered log entries are written out.
    # This delegates to the target logger's flush method, which may flush buffers to disk,
    # external services, or other destinations depending on the logger's configuration.
    #
    # @return [void]
    def flush
      @logger.flush
    end

    # Expose the underlying stream if any.
    #
    # @return [IO, Lumberjack::Device, nil]
    # @api private
    def dev
      @logger.device&.dev
    end
  end
end
