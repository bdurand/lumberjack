# frozen_string_literal: true

module Lumberjack
  # Abstract base class defining the interface for logging output devices.
  # Devices are responsible for the final output of log entries to various
  # destinations such as files, streams, databases, or external services.
  #
  # This class establishes the contract that all concrete device implementations
  # must follow, with the `write` method being the only required implementation.
  # Additional lifecycle methods (`close`, `flush`, `reopen`) and configuration
  # methods (`datetime_format`) are optional but provide standardized interfaces
  # for device management.
  #
  # The device architecture allows for flexible log output handling while
  # maintaining consistent behavior across different output destinations.
  # Devices receive formatted LogEntry objects and are responsible for their
  # final serialization and delivery.
  #
  # @abstract Subclass and implement {#write} to create a concrete device
  # @see Lumberjack::Device::Writer File-based output device
  # @see Lumberjack::Device::LoggerWrapper Ruby Logger compatibility device
  # @see Lumberjack::Device::Multi Multiple device routing
  # @see Lumberjack::Device::Null Silent device for testing
  # @see Lumberjack::Device::Test In-memory device for testing
  class Device
    require_relative "device/writer"
    require_relative "device/logger_file"
    require_relative "device/logger_wrapper"
    require_relative "device/multi"
    require_relative "device/null"
    require_relative "device/test"

    # Write a log entry to the device. This is the core method that all device
    # implementations must provide. The method receives a fully formatted
    # LogEntry object and is responsible for outputting it to the target
    # destination.
    #
    # @param entry [Lumberjack::LogEntry] The log entry to write to the device
    # @return [void]
    # @abstract Subclasses must implement this method
    # @raise [NotImplementedError] If called on the abstract base class
    def write(entry)
      raise NotImplementedError
    end

    # Close the device and release any resources. The default implementation
    # calls flush to ensure any buffered data is written before closing.
    # Subclasses should override this method if they need to perform specific
    # cleanup operations such as closing file handles or network connections.
    #
    # @return [void]
    def close
      flush
    end

    # Reopen the device, optionally with a new log destination. The default
    # implementation calls flush to ensure data consistency. This method is
    # typically used for log rotation scenarios or when changing output
    # destinations dynamically.
    #
    # @param logdev [Object, nil] Optional new log device or destination
    # @return [void]
    def reopen(logdev = nil)
      flush
    end

    # Flush any buffered data to the output destination. The default
    # implementation is a no-op since not all devices use buffering.
    # Subclasses that implement buffering should override this method
    # to ensure data is written to the final destination.
    #
    # @return [void]
    def flush
    end

    # Get the current datetime format string used for timestamp formatting.
    # The default implementation returns nil, indicating no specific format
    # is set. Subclasses may override this to provide device-specific
    # timestamp formatting.
    #
    # @return [String, nil] The datetime format string, or nil if not set
    def datetime_format
    end

    # Set the datetime format string for timestamp formatting. The default
    # implementation is a no-op. Subclasses that support configurable
    # timestamp formatting should override this method to store and apply
    # the specified format.
    #
    # @param format [String, nil] The datetime format string to use for timestamps
    # @return [void]
    def datetime_format=(format)
    end

    # Expose the underlying stream if any.
    #
    # @return [IO, Lumberjacke::Device, nil]
    # @api private
    def dev
      self
    end
  end
end
