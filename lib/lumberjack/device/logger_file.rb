# frozen_string_literal: true

module Lumberjack
  # A file-based logging device that extends the Writer device with automatic
  # log rotation capabilities. This device wraps Ruby's standard Logger::LogDevice
  # to provide file size-based and time-based log rotation while maintaining
  # compatibility with the Lumberjack device interface.
  #
  # The device supports all the rotation features available in Ruby's Logger,
  # including maximum file size limits, automatic rotation based on age, and
  # automatic cleanup of old log files. This makes it suitable for production
  # environments where log management is crucial.
  #
  # @example Basic file logging
  #   device = Lumberjack::Device::LoggerFile.new("/var/log/app.log")
  #
  # @example With size-based rotation (10MB files, keep 5 old files)
  #   device = Lumberjack::Device::LoggerFile.new(
  #     "/var/log/app.log",
  #     shift_size: 10 * 1024 * 1024,  # 10MB
  #     shift_age: 5                    # Keep 5 old files
  #   )
  #
  # @example With daily rotation
  #   device = Lumberjack::Device::LoggerFile.new(
  #     "/var/log/app.log",
  #     shift_age: "daily"
  #   )
  #
  # @example With weekly rotation
  #   device = Lumberjack::Device::LoggerFile.new(
  #     "/var/log/app.log",
  #     shift_age: "weekly"
  #   )
  #
  # @see Device::Writer
  # @see Logger::LogDevice
  class Device::LoggerFile < Device::Writer
    # Initialize a new LoggerFile device with automatic log rotation capabilities.
    # This constructor wraps Ruby's Logger::LogDevice while filtering options to
    # only pass supported parameters, ensuring compatibility across Ruby versions.
    #
    # @param stream [String, IO] The log destination. Can be a file path string
    #   or an IO object. When a string path is provided, the file will be created
    #   if it doesn't exist, and parent directories will be created as needed.
    # @param options [Hash] Configuration options for the log device. All options
    #   supported by Logger::LogDevice are accepted, including:
    #   - `:shift_age` - Number of old files to keep, or rotation frequency
    #     ("daily", "weekly", "monthly")
    #   - `:shift_size` - Maximum file size in bytes before rotation
    #   - `:shift_period_suffix` - Suffix to add to rotated log files
    #   - `:binmode` - Whether to open the log file in binary mode
    def initialize(stream, options = {})
      # Filter options to only include keyword arguments supported by Logger::LogDevice#initialize
      supported_kwargs = ::Logger::LogDevice.instance_method(:initialize).parameters
        .select { |type, _| type == :key || type == :keyreq }
        .map { |_, name| name }

      filtered_options = options.slice(*supported_kwargs)

      logdev = ::Logger::LogDevice.new(stream, **filtered_options)

      super(logdev, options)
    end

    # Get the file system path of the current log file. This method provides
    # access to the actual file path being written to, which is useful for
    # monitoring, log analysis tools, or other file-based operations.
    #
    # @return [String] The absolute file system path of the current log file
    def path
      stream.filename
    end
  end
end
