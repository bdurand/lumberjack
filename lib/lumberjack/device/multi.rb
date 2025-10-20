# frozen_string_literal: true

module Lumberjack
  # A multiplexing logging device that broadcasts log entries to multiple target
  # devices simultaneously. This device enables sophisticated logging architectures
  # where a single log entry needs to be processed by multiple output destinations,
  # each potentially with different formatting, filtering, or storage mechanisms.
  #
  # The Multi device acts as a fan-out mechanism, ensuring that all configured
  # devices receive every log entry while maintaining independent processing
  # pipelines. This is particularly useful for creating redundant logging systems,
  # separating log streams by concern, or implementing complex routing logic.
  #
  # All device lifecycle methods (flush, close, reopen) are propagated to all
  # child devices, ensuring consistent state management across the entire
  # logging topology.
  #
  # @example Basic multi-device setup
  #   file_device = Lumberjack::Device::Writer.new("/var/log/app.log")
  #   console_device = Lumberjack::Device::Writer.new(STDOUT, template: "{{message}}")
  #   multi_device = Lumberjack::Device::Multi.new(file_device, console_device)
  class Device::Multi < Device
    attr_reader :devices

    # Initialize a new Multi device with the specified target devices. The device
    # accepts multiple devices either as individual arguments or as arrays,
    # automatically flattening nested arrays for convenient configuration.
    #
    # @param devices [Array<Lumberjack::Device>] The target devices to receive
    #   log entries. Can be passed as individual arguments or arrays. All devices
    #   must implement the standard Lumberjack::Device interface.
    #
    # @example Individual device arguments
    #   multi = Multi.new(file_device, console_device, database_device)
    def initialize(*devices)
      @devices = devices.flatten
    end

    # Broadcast a log entry to all configured devices. Each device receives the
    # same LogEntry object and processes it according to its own configuration,
    # formatting, and output logic. Devices are processed sequentially in the
    # order they were configured.
    #
    # @param entry [Lumberjack::LogEntry] The log entry to broadcast to all devices
    # @return [void]
    def write(entry)
      devices.each do |device|
        device.write(entry)
      end
    end

    # Flush all configured devices to ensure buffered data is written to their
    # respective destinations. This method calls flush on each device in sequence,
    # ensuring consistent state across all output destinations.
    #
    # @return [void]
    def flush
      devices.each do |device|
        device.flush
      end
    end

    # Close all configured devices and release their resources. This method calls
    # close on each device in sequence, ensuring proper cleanup of file handles,
    # network connections, and other resources across all output destinations.
    #
    # @return [void]
    def close
      devices.each do |device|
        device.close
      end
    end

    # Reopen all configured devices, optionally with a new log destination.
    # This method calls reopen on each device in sequence, which is typically
    # used for log rotation scenarios or when changing output destinations.
    #
    # @param logdev [Object, nil] Optional new log device or destination to pass
    #   to each device's reopen method
    # @return [void]
    def reopen(logdev = nil)
      devices.each do |device|
        device.reopen(logdev = nil)
      end
    end

    # Get the datetime format from the first device that has one configured.
    # This method searches through the configured devices and returns the
    # datetime format from the first device that provides one.
    #
    # @return [String, nil] The datetime format string from the first device
    #   that has one configured, or nil if no devices have a format set
    def datetime_format
      devices.detect(&:datetime_format).datetime_format
    end

    # Set the datetime format on all configured devices that support it.
    # This method propagates the format setting to each device, allowing
    # coordinated timestamp formatting across all output destinations.
    #
    # @param format [String] The datetime format string to apply to all devices
    # @return [void]
    def datetime_format=(format)
      devices.each do |device|
        device.datetime_format = format
      end
    end
  end
end
