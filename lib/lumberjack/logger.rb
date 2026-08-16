# frozen_string_literal: true

module Lumberjack
  # Lumberjack::Logger is a thread-safe, feature-rich logging implementation that extends Ruby's standard
  # library Logger class with advanced capabilities for structured logging.
  #
  # Key features include:
  # - Structured logging with attributes (key-value pairs) attached to log entries
  # - Context isolation for scoping logging behavior to specific code blocks
  # - Flexible output devices supporting files, streams, and custom destinations
  # - Customizable formatters for messages and attributes
  #
  # The Logger maintains full API compatibility with Ruby's standard Logger while adding
  # powerful extensions for modern logging needs.
  #
  # @example Basic usage
  #   logger = Lumberjack::Logger.new(STDOUT)
  #   logger.info("Starting processing")
  #   logger.debug("Processing options #{options.inspect}")
  #   logger.fatal("OMG the application is on fire!")
  #
  # @example Structured logging with attributes
  #   logger = Lumberjack::Logger.new("/var/log/app.log")
  #   logger.tag(request_id: "abc123") do
  #     logger.info("User logged in", user_id: 123, ip: "192.168.1.1")
  #     logger.info("Processing request")  # Will include request_id: "abc123"
  #   end
  #
  # @example Log rotation
  #   # Keep 10 files, rotate when each reaches 10MB
  #   logger = Lumberjack::Logger.new("/var/log/app.log", 10, 10 * 1024 * 1024)
  #
  # @example Using different devices
  #   logger = Lumberjack::Logger.new("logs/application.log")  # Log to file
  #   logger = Lumberjack::Logger.new(STDOUT, template: "{{severity}} - {{message}}")  # Log to a stream with a template
  #   logger = Lumberjack::Logger.new(:test)  # Log to an in memory buffer for testing
  #   logger = Lumberjack::Logger.new(another_logger) # Proxy logs to another logger
  #   logger = Lumberjack::Logger.new(MyDevice.new)  # Log to a custom Lumberjack::Device
  #
  # @example Logging to multiple devices with an array
  #   logger = Lumberjack::Logger.new(["/var/log/app.log", [:stdout, {template: "{{message}}"}]])
  #
  # Log entries are written to a logging Device if their severity meets or exceeds the log level.
  # Each log entry records the log message and severity along with the time it was logged, the
  # program name, process id, and an optional hash of attributes. Messages are converted to strings
  # using a Formatter associated with the logger.
  #
  # @see Lumberjack::ContextLogger
  # @see Lumberjack::Device
  # @see Lumberjack::Template
  # @see Lumberjack::EntryFormatter
  class Logger < ::Logger
    include ContextLogger

    # Create a new logger to log to a Device.
    #
    # The +device+ argument can be in any one of several formats:
    # - A symbol for a device name (e.g. :null, :test). You can call +Lumberjack::DeviceRegistry.registered_devices+ for a list.
    # - A stream
    # - A file path string or +Pathname+
    # - A +Lumberjack::Device+ object
    # - An object with a +write+ method will be wrapped in a Device::Writer
    # - An array of any of the above will open a Multi device that will send output to all devices.
    #
    # @param logdev [Lumberjack::Device, IO, Symbol, String, Pathname] The device to log to.
    #   If this is a symbol, the device will be looked up from the DeviceRegistry. If it is
    #   a string or a Pathname, the logs will be sent to the corresponding file path.
    # @param shift_age [Integer, String, Symbol] If this is an integer greater than zero, then
    #   log files will be rolled when they get to the size specified in shift_size and the number of
    #   files to keep will be determined by this value. Otherwise it will be interpreted as a date
    #   rolling value and must be one of "daily", "weekly", or "monthly". This parameter has no
    #   effect unless the device parameter is a file path or file stream.
    # @param shift_size [Integer] The size in bytes of the log files before rolling them. This can
    #   be passed as a string with a unit suffix of K, M, or G (e.g. "10M" for 10 megabytes).
    # @param level [Integer, Symbol, String] The logging level below which messages will be ignored.
    # @param progname [String] The name of the program that will be recorded with each log entry.
    # @param formatter [Lumberjack::EntryFormatter, Lumberjack::Formatter, ::Logger::Formatter, :default, #call]
    #   The formatter to use for outputting messages to the log. If this is a Lumberjack::EntryFormatter
    #   or a Lumberjack::Formatter, it will be used to format structured log entries.
    #   You can also pass the value +:default+ to use the default message formatter which formats
    #   non-primitive objects with +inspect+ and includes the backtrace in exceptions.
    #
    #   For compatibility with the standard library Logger when writing to a stream, you can also
    #   pass in a +::Logger::Formatter+ object or a callable object that takes exactly 4 arguments
    #   (severity, time, progname, msg).
    # @param datetime_format [String] The format to use for log timestamps.
    # @param binmode [Boolean] Whether to open the log file in binary mode.
    # @param shift_period_suffix [String] The suffix to use for the shifted log file names.
    # @param kwargs [Hash] Additional device-specific options. These will be passed through when creating
    #   a device from the logdev argument.
    # @return [Lumberjack::Logger] A new logger instance.
    def initialize(logdev, shift_age = 0, shift_size = 1048576,
      level: DEBUG, progname: nil, formatter: nil, datetime_format: nil,
      binmode: false, shift_period_suffix: "%Y%m%d", **kwargs)
      init_context_locals!
      @recursion_guard_key = :"lumberjack_logging_#{object_id}"

      self.isolation_level = kwargs.delete(:isolation_level) || Lumberjack.isolation_level

      # Include standard args that affect devices with the optional kwargs which may
      # contain device specific options.
      device_options = kwargs.merge(shift_age: shift_age, shift_size: size_with_units(shift_size), binmode: binmode, shift_period_suffix: shift_period_suffix)
      device_options[:standard_logger_formatter] = formatter if standard_logger_formatter?(formatter)

      @logdev = Device.open_device(logdev, device_options)

      @context = Context.new
      self.level = level || DEBUG
      self.progname = progname

      self.formatter = build_entry_formatter(formatter)
      self.datetime_format = datetime_format if datetime_format

      @closed = false
    end

    # Get the logging device that is used to write log entries.
    #
    # @return [Lumberjack::Device] The logging device.
    def device
      @logdev
    end

    # Set the logging device to a new device.
    #
    # @param device [Lumberjack::Device] The new logging device.
    # @return [void]
    def device=(device)
      @logdev = Device.open_device(device, {})
    end

    # Set the formatter used for log entries. This can be an EntryFormatter, a standard Logger::Formatter,
    # or any callable object that formats log entries.
    #
    # @param value [Lumberjack::EntryFormatter, ::Logger::Formatter, #call] The formatter to use.
    # @return [void]
    def formatter=(value)
      @formatter = build_entry_formatter(value)
    end

    # Get the timestamp format on the device if it has one.
    #
    # @return [String, nil] The timestamp format or nil if the device doesn't support it.
    def datetime_format
      device.datetime_format if device.respond_to?(:datetime_format)
    end

    # Set the timestamp format on the device if it is supported.
    #
    # @param format [String] The timestamp format.
    # @return [void]
    def datetime_format=(format)
      if device.respond_to?(:datetime_format=)
        device.datetime_format = format
      end
    end

    # Get the message formatter used to format log messages.
    #
    # @return [Lumberjack::Formatter] The message formatter.
    def message_formatter
      formatter.message_formatter
    end

    # Set the message formatter used to format log messages.
    #
    # @param value [Lumberjack::Formatter] The message formatter to use.
    # @return [void]
    def message_formatter=(value)
      formatter.message_formatter = value
    end

    # Get the attribute formatter used to format log entry attributes.
    #
    # @return [Lumberjack::AttributeFormatter] The attribute formatter.
    def attribute_formatter
      formatter.attribute_formatter
    end

    # Set the attribute formatter used to format log entry attributes.
    #
    # @param value [Lumberjack::AttributeFormatter] The attribute formatter to use.
    # @return [void]
    def attribute_formatter=(value)
      formatter.attribute_formatter = value
    end

    # Flush the logging device. Messages are not guaranteed to be written until this method is called.
    #
    # @return [void]
    def flush
      device.flush
      nil
    end

    # Close the logging device.
    #
    # @return [void]
    def close
      flush
      device.close if device.respond_to?(:close)
      @closed = true
    end

    # Returns +true+ if the logging device is closed.
    #
    # @return [Boolean] +true+ if the logging device is closed.
    def closed?
      return true if @closed

      device.respond_to?(:closed?) && device.closed?
    end

    # Reopen the logging device.
    #
    # @param logdev [Object] passed through to the logging device.
    # @return [Lumberjack::Logger] self
    def reopen(logdev = nil)
      @closed = false
      device.reopen(logdev) if device.respond_to?(:reopen)
      self
    end

    # Add an entry to the log.
    #
    # @param severity [Integer, Symbol, String] The severity of the message.
    # @param message [Object] The message to log.
    # @param progname [String] The name of the program that is logging the message.
    # @param attributes [Hash] The attributes to add to the log entry.
    # @return [void]
    # @api private
    def add_entry(severity, message, progname = nil, attributes = nil)
      return false unless device

      # Prevent infinite recursion if logging is attempted from within a logging call.
      # The guard is stored in fiber-local storage since recursion is a property of the
      # current call stack, which belongs to exactly one fiber.
      if Thread.current[@recursion_guard_key]
        log_to_stderr(severity, message)
        return false
      end

      severity = Severity.label_to_level(severity) unless severity.is_a?(Integer)

      begin
        Thread.current[@recursion_guard_key] = true

        locals = current_context_locals
        time = Time.now
        progname ||= locals&.context&.progname || default_context&.progname
        attributes = nil unless attributes.is_a?(Hash)
        attributes = merge_all_attributes(locals, attributes)
        message, attributes = formatter.format(message, attributes) if formatter

        entry = Lumberjack::LogEntry.new(time, severity, message, progname, Process.pid, attributes)

        write_to_device(entry)
      ensure
        Thread.current[@recursion_guard_key] = nil
      end

      true
    end

    # Return a human-readable representation of the logger showing its key configuration.
    #
    # @return [String] A string representation of the logger.
    def inspect
      formatted_object_id = object_id.to_s(16).rjust(16, "0")
      "#<Lumberjack::Logger:0x#{formatted_object_id} level:#{Severity.level_to_label(level)} device:#{device.class.name} progname:#{progname.inspect} attributes:#{attributes.inspect}>"
    end

    private

    def default_context
      @context
    end

    def write_to_device(entry) # :nodoc:
      device.write(entry)
    rescue => e
      err = e.class.name.dup
      err << ": #{e.message}" unless e.message.to_s.empty?
      err << " at #{e.backtrace.first}" if e.backtrace
      $stderr.write("#{err}#{Lumberjack::LINE_SEPARATOR}#{entry}#{Lumberjack::LINE_SEPARATOR}") # rubocop:disable Style/StderrPuts

      raise e if Lumberjack.raise_logger_errors?
    end

    def build_entry_formatter(formatter) # :nodoc:
      return formatter if formatter.is_a?(Lumberjack::EntryFormatter)

      entry_formatter = Lumberjack::EntryFormatter.new

      message_formatter = formatter if formatter.is_a?(Lumberjack::Formatter)
      message_formatter = Lumberjack::Formatter.default if formatter == :default
      entry_formatter.message_formatter = message_formatter if message_formatter

      entry_formatter
    end

    def standard_logger_formatter?(formatter)
      return false if formatter.is_a?(Lumberjack::EntryFormatter)
      return false if formatter.is_a?(Lumberjack::Formatter)
      return true if formatter.is_a?(::Logger::Formatter)

      takes_exactly_n_call_args?(formatter, 4)
    end

    # Convert a size string with optional unit suffix to an integer size in bytes.
    # Allowed suffixes are K, M, and G (case insensitive) for kilobytes, megabytes, and gigabytes.
    #
    # @param size [String, Integer] The size string to convert.
    # @return [Integer] The size in bytes.
    def size_with_units(size)
      return size unless size.is_a?(String) && size.match?(/\A\d+(\.\d+)?[KMG]?\z/i)

      multiplier = case size[-1].upcase
      when "K" then 1024
      when "M" then 1024 * 1024
      when "G" then 1024 * 1024 * 1024
      else 1
      end

      (size.to_f * multiplier).round
    end

    def takes_exactly_n_call_args?(callable, count)
      params = if callable.is_a?(Proc)
        callable.parameters
      elsif callable.respond_to?(:call)
        callable.method(:call).parameters
      end

      return false unless params

      positional_arg_count = params.count do |type, _name|
        type == :req || type == :opt
      end

      has_forbidden_args = params.any? do |type, _name|
        [:rest, :keyreq, :key, :keyrest].include?(type)
      end

      positional_arg_count == 4 && !has_forbidden_args
    end

    def log_to_stderr(severity, message)
      severity = Severity.coerce(severity)
      severity_label = Severity.level_to_label(severity)
      $stderr.write("Recursive logging detected; you cannot write new log entries while logging other entries: #{severity_label} #{message}\n")
    end
  end
end
