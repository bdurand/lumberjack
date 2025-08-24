# frozen_string_literal: true

module Lumberjack
  # Logger is a thread-safe, feature-rich logging implementation that extends Ruby's standard
  # library Logger class with advanced capabilities for structured logging.
  #
  # Key features include:
  # - Structured logging with attributes (key-value pairs) attached to log entries
  # - Context isolation for scoping logging behavior to specific code blocks
  # - Flexible output devices supporting files, streams, and custom destinations
  # - Customizable formatters for messages and attributes
  # - Built-in log rotation and file management
  # - Thread and fiber safety for concurrent applications
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
  #   logger.info("User logged in", user_id: 123, ip: "192.168.1.1")
  #   logger.tag(request_id: "abc123") do
  #     logger.info("Processing request")  # Will include request_id: "abc123"
  #   end
  #
  # @example Log rotation
  #   # Keep 10 files, rotate when each reaches 10MB
  #   logger = Lumberjack::Logger.new("/var/log/app.log", 10, 10 * 1024 * 1024)
  #
  # @example Using different devices
  #   logger = Lumberjack::Logger.new("logs/application.log")  # Log to file
  #   logger = Lumberjack::Logger.new(STDOUT, template: ":severity - :message")  # Log to a stream with a template
  #   logger = Lumberjack::Logger.new(:test)  # Log to a buffer for testing
  #   logger = Lumberjack::Logger.new(another_logger) # Proxy logs to another logger
  #   logger = Lumberjack::Logger.new(MyDevice.new)  # Log to a custom Lumberjack::Device
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
    # - A Device object will be used directly
    # - An object with a +write+ method will be wrapped in a Device::Writer
    # - The symbol +:null+ creates a Null device that discards all output
    # - The symbol +:test+ creates a Test device for capturing output in tests
    # - A file path string creates a Device::LogFile for file-based logging
    #
    # @param device [Lumberjack::Device, Object, Symbol, String] The device to log to.
    # @param shift_age [Integer, String, Symbol] If this is an integer greater than zero, then
    #   log files will be rolled when they get to the size specified in shift_size and the number of
    #   files to keep will be determined by this value. Otherwise it will be interpreted as a date
    #   rolling value and must be one of "daily", "weekly", or "monthly". This parameter has no
    #   effect unless the device parameter is a file path or file stream.
    # @param shift_size [Integer] The size in bytes of the log files before rolling them.
    # @param level [Integer, Symbol, String] The logging level below which messages will be ignored.
    # @param progname [String] The name of the program that will be recorded with each log entry.
    # @param formatter [Lumberjack::EntryFormatter, Lumberjack::Formatter, ::Logger::Formatter, #call]
    #   The formatter to use for outputting messages to the log. If this is a Lumberjack::EntryFormatter
    #   or a Lumberjack::Formatter, it will be used to format structured log entries. If it is
    #   a ::Logger::Formatter or a callable object that takes 4 arguments (severity, time, progname, msg),
    #   it will be used to format log entries in lieu of the `template` argument when writing to a
    #   stream.
    # @param datetime_format [String] The format to use for log timestamps.
    # @param binmode [Boolean] Whether to open the log file in binary mode.
    # @param shift_period_suffix [String] The suffix to use for the shifted log file names.
    # @param template [String] The template to use for serializing log entries to a string.
    # @param message_formatter [Lumberjack::Formatter] The formatter to use for formatting log messages.
    # @param attribute_formatter [Lumberjack::AttributeFormatter] The formatter to use for formatting attributes.
    # @param kwargs [Hash] Additional device-specific options.
    # @return [Lumberjack::Logger] A new logger instance.
    def initialize(logdev, shift_age = 0, shift_size = 1048576,
      level: DEBUG, progname: nil, formatter: nil, datetime_format: nil,
      binmode: false, shift_period_suffix: "%Y%m%d",
      template: nil, message_formatter: nil, attribute_formatter: nil, **kwargs)
      init_fiber_locals!

      if shift_age.is_a?(Hash)
        raise ArgumentError.new("options must be passed as keyword arguments instead of a Hash")
      end

      # Include standard args that affect devices with the optional kwargs which may
      # contain device specific options.
      device_options = kwargs.merge(shift_age: shift_age, shift_size: shift_size, binmode: binmode, shift_period_suffix: shift_period_suffix)
      device_options[:template] = template unless template.nil?
      device_options[:standard_logger_formatter] = formatter if standard_logger_formatter?(formatter)

      if device_options.include?(:tag_formatter)
        Utils.deprecated(:tag_formatter, "Use attribute_formatter instead.") do
          attribute_formatter ||= device_options.delete(:tag_formatter)
        end
      end

      if device_options.include?(:roll) && shift_age != 0
        Utils.deprecated(:roll, "Use shift_age instead.") do
          shift_age = device_options.delete(:roll)
        end
      end

      if device_options.include?(:max_size)
        Utils.deprecated(:max_size, "Use shift_size instead.") do
          shift_age = 10
          shift_size = device_options.delete(:max_size)
        end
      end

      @logdev = open_device(logdev, device_options)

      @context = Context.new
      self.level = level || DEBUG
      self.progname = progname

      self.formatter = build_entry_formatter(formatter, message_formatter, attribute_formatter)
      self.datetime_format = datetime_format if datetime_format

      @closed = false # TODO
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
      @logdev = device.nil? ? nil : open_device(device, {})
    end

    # Set the formatter used for log entries. This can be an EntryFormatter, a standard Logger::Formatter,
    # or any callable object that formats log entries.
    #
    # @param value [Lumberjack::EntryFormatter, ::Logger::Formatter, #call] The formatter to use.
    # @return [void]
    def formatter=(value)
      @formatter = build_entry_formatter(value, nil, nil)
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
      formatter.attributes.attribute_formatter
    end

    # Set the attribute formatter used to format log entry attributes.
    #
    # @param value [Lumberjack::AttributeFormatter] The attribute formatter to use.
    # @return [void]
    def attribute_formatter=(value)
      formatter.attribute_formatter = value
    end

    # @deprecated Use {#attribute_formatter} instead.
    def tag_formatter
      Utils.deprecated(:tag_formatter, "Use attribute_formatter instead.") do
        formatter.attributes.attribute_formatter
      end
    end

    # @deprecated Use {#attribute_formatter=} instead.
    def tag_formatter=(value)
      Utils.deprecated(:tag_formatter=, "Use attribute_formatter= instead.") do
        formatter.attributes.attribute_formatter = value
      end
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
      @closed
    end

    # Reopen the logging device.
    #
    # @param logdev [Object] passed through to the logging device.
    def reopen(logdev = nil)
      @closed = false
      device.reopen(logdev) if device.respond_to?(:reopen)
    end

    # Set the program name that is associated with log messages. If a block
    # is given, the program name will be valid only within the block.
    #
    # @param value [String] The program name to use.
    # @return [void]
    # @deprecated Use with_progname or progname= instead.
    def set_progname(value, &block)
      Utils.deprecated(:set_progname, "Use with_progname or progname= instead.") do
        if block
          with_progname(value, &block)
        else
          self.progname = value
        end
      end
    end

    # Use tag! instead
    #
    # @return [void]
    # @deprecated Use {#tag!} instead.
    def tag_globally(tags)
      Utils.deprecated(:tag_globally, "Use tag! instead.") do
        tag!(tags)
      end
    end

    # Use context? instead
    #
    # @return [Boolean]
    # @deprecated Use {#in_context?} instead.
    def in_tag_context?
      Utils.deprecated(:in_tag_context?, "Use context? instead.") do
        context?
      end
    end

    # Remove a tag from the current context block. If this is called inside a context block,
    # the attributes will only be removed for the duration of that block. Otherwise they will be removed
    # from the global attributes.
    #
    # @param tag_names [Array<String, Symbol>] The attributes to remove.
    # @return [void]
    # @deprecated Use untag or untag! instead.
    def remove_tag(*tag_names)
      Utils.deprecated(:remove_tag, "Use untag or untag! instead.") do
        attributes = current_context&.attributes
        AttributesHelper.new(attributes).delete(*tag_names) if attributes
      end
    end

    # Alias for with_level for compatibility with ActiveSupport loggers. This functionality
    # has been moved to the lumberjack_rails gem.
    #
    # @see with_level
    # @deprecated This implementation is deprecated. Install the lumberjack_rails gem for full support.
    def log_at(level, &block)
      deprecation_message = "Install the lumberjack_rails gem for full support of the log_at method."
      Utils.deprecated(:log_at, deprecation_message) do
        with_level(level, &block)
      end
    end

    # Alias for with_level for compatibilty with ActiveSupport loggers. This functionality
    # has been moved to the lumberjack_rails gem.
    #
    # @see with_level
    # @deprecated This implementation is deprecated. Install the lumberjack_rails gem for full support.
    def silence(level = Logger::ERROR, &block)
      deprecation_message = "Install the lumberjack_rails gem for full support of the silence method."
      Utils.deprecated(:silence, deprecation_message) do
        with_level(level, &block)
      end
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
      return false if fiber_local_value(:logging)

      severity = Severity.label_to_level(severity) unless severity.is_a?(Integer)

      begin
        set_fiber_local_value(:logging, true) # protection from infinite loops

        time = Time.now
        progname ||= self.progname
        attributes = nil unless attributes.is_a?(Hash)
        attributes = merge_attributes(merge_all_attributes, attributes)
        message, attributes = formatter.format(message, attributes) if formatter

        entry = Lumberjack::LogEntry.new(time, severity, message, progname, Process.pid, attributes)

        write_to_device(entry)
      ensure
        set_fiber_local_value(:logging, nil)
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
      $stderr.write("#{err}\n#{entry}\n") # rubocop:disable Style/StderrPuts
    end

    # Open a logging device.
    def open_device(device, options) # :nodoc:
      device = device.to_s if device.is_a?(Pathname)

      if device.nil? || device == :null
        Device::Null.new
      elsif device == :test
        Device::Test.new(options)
      elsif device.is_a?(Device)
        device
      elsif device.is_a?(ContextLogger)
        Device::LoggerWrapper.new(device)
      elsif io_but_not_file_stream?(device)
        Device::Writer.new(device, options)
      else
        Device::LoggerFile.new(device, options)
      end
    end

    def io_but_not_file_stream?(object)
      return false unless object.respond_to?(:write)
      return true if object.respond_to?(:tty?) && object.tty?
      return false if object.respond_to?(:path) && object.path
      true
    end

    def build_entry_formatter(formatter, message_formatter, attribute_formatter) # :nodoc:
      entry_formatter = formatter if formatter.is_a?(Lumberjack::EntryFormatter)

      unless entry_formatter
        message_formatter ||= formatter if formatter.is_a?(Lumberjack::Formatter)
        entry_formatter = Lumberjack::EntryFormatter.new
      end

      entry_formatter.message_formatter = message_formatter if message_formatter
      entry_formatter.attribute_formatter = attribute_formatter if attribute_formatter

      entry_formatter
    end

    def standard_logger_formatter?(formatter)
      return false if formatter.is_a?(Lumberjack::EntryFormatter)
      return false if formatter.is_a?(Lumberjack::Formatter)
      return true if formatter.is_a?(::Logger::Formatter)

      takes_exactly_n_call_args?(formatter, 4)
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
  end
end
