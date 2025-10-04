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
    #   effect unless the device parameter is a file path or file stream. This can also be
    #   specified with the :roll keyword argument.
    # @param shift_size [Integer] The size in bytes of the log files before rolling them. This can
    #   be passed as a string with a unit suffix of K, M, or G (e.g. "10M" for 10 megabytes).
    #   This can also be specified with the :max_size keyword argument.
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
      init_fiber_locals!

      if shift_age.is_a?(Hash)
        Lumberjack::Utils.deprecated("Logger.new(options)", "Passing a Hash as the second argument to Logger.new is deprecated and will be removed in version 2.1; use keyword arguments instead.")
        options = shift_age
        level = options[:level] if options.include?(:level)
        progname = options[:progname] if options.include?(:progname)
        formatter = options[:formatter] if options.include?(:formatter)
        datetime_format = options[:datetime_format] if options.include?(:datetime_format)
        kwargs = options.merge(kwargs)
      end

      # Include standard args that affect devices with the optional kwargs which may
      # contain device specific options.
      device_options = kwargs.merge(shift_age: shift_age, shift_size: size_with_units(shift_size), binmode: binmode, shift_period_suffix: shift_period_suffix)
      device_options[:standard_logger_formatter] = formatter if standard_logger_formatter?(formatter)

      if device_options.include?(:roll)
        Utils.deprecated("Logger.options(:roll)", "Lumberjack::Logger :roll option is deprecated and will be removed in version 2.1; use the shift_age argument instead.")
        device_options[:shift_age] = device_options.delete(:roll) unless shift_age != 0
      end

      if device_options.include?(:max_size)
        Utils.deprecated("Logger.options(:max_size)", "Lumberjack::Logger :max_size option is deprecated and will be removed in version 2.1; use the shift_size argument instead.")
        device_options[:shift_age] = 10 if shift_age == 0
        device_options[:shift_size] = device_options.delete(:max_size)
      end

      message_formatter = nil
      if device_options.include?(:message_formatter)
        Utils.deprecated("Logger.options(:message_formatter)", "Lumberjack::Logger :message_formatter option is deprecated and will be removed in version 2.1; use the formatter argument instead to specify an EntryFormatter.")
        message_formatter = device_options.delete(:message_formatter)
      end

      attribute_formatter = nil
      if device_options.include?(:tag_formatter)
        Utils.deprecated("Logger.options(:tag_formatter)", "Lumberjack::Logger :tag_formatter option is deprecated and will be removed in version 2.1; use the formatter argument instead to specify an EntryFormatter.")
        attribute_formatter = device_options.delete(:tag_formatter)
      end

      @logdev = Device.open_device(logdev, device_options)

      @context = Context.new
      self.level = level || DEBUG
      self.progname = progname

      self.formatter = build_entry_formatter(formatter, message_formatter, attribute_formatter)
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
      formatter.attribute_formatter
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
      Utils.deprecated("Logger#tag_formatter", "Lumberjack::Logger#tag_formatter is deprecated and will be removed in version 2.1; use attribute_formatter instead.") do
        formatter.attributes.attribute_formatter
      end
    end

    # @deprecated Use {#attribute_formatter=} instead.
    def tag_formatter=(value)
      Utils.deprecated("Logger#tag_formatter=", "Lumberjack::Logger#tag_formatter= is deprecated and will be removed in version 2.1; use attribute_formatter= instead.") do
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

    # Set the program name that is associated with log messages. If a block
    # is given, the program name will be valid only within the block.
    #
    # @param value [String] The program name to use.
    # @return [void]
    # @deprecated Use with_progname or progname= instead.
    def set_progname(value, &block)
      Utils.deprecated("Logger#set_progname", "Lumberjack::Logger#set_progname is deprecated and will be removed in version 2.1; use with_progname or progname= instead.") do
        if block
          with_progname(value, &block)
        else
          self.progname = value
        end
      end
    end

    # Alias method for #attributes to provide backward compatibility with version 1.x API. This
    # method will eventually be removed.
    #
    # @return [Hash]
    # @deprecated Use {#attributes} instead
    def tags
      Utils.deprecated("Logger#tags", "Lumberjack::Logger#tags is deprecated and will be removed in version 2.1; use attributes instead.") do
        attributes
      end
    end

    # Alias method for #attribute_value to provide backward compatibility with version 1.x API. This
    # method will eventually be removed.
    #
    # @return [Hash]
    # @deprecated Use {#attribute_value} instead
    def tag_value(name)
      Utils.deprecated("Logger#tag_value", "Lumberjack::Logger#tag_value is deprecated and will be removed in version 2.1; use attribute_value instead.") do
        attribute_value(name)
      end
    end

    # Use tag! instead
    #
    # @return [void]
    # @deprecated Use {#tag!} instead.
    def tag_globally(tags)
      Utils.deprecated("Logger#tag_globally", "Lumberjack::Logger#tag_globally is deprecated and will be removed in version 2.1; use tag! instead.") do
        tag!(tags)
      end
    end

    # Use context? instead
    #
    # @return [Boolean]
    # @deprecated Use {#in_context?} instead.
    def in_tag_context?
      Utils.deprecated("Logger#in_tag_context?", "Lumberjack::Logger#in_tag_context? is deprecated and will be removed in version 2.1; use in_context? instead.") do
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
      Utils.deprecated("Logger#remove_tag", "Lumberjack::Logger#remove_tag is deprecated and will be removed in version 2.1; use untag or untag! instead.") do
        attributes = current_context&.attributes
        AttributesHelper.new(attributes).delete(*tag_names) if attributes
      end
    end

    # Alias for append_to(:tagged) for compatibility with ActiveSupport support in Lumberjack 1.x.
    # This functionality has been moved to the lumberjack_rails gem. Note that in that gem the
    # tags are added to the :tags attribute instead of the :tagged attribute.
    #
    # @see append_to
    # @deprecated This implementation is deprecated. Install the lumberjack_rails gem for full support.
    def tagged(*tags, &block)
      deprecation_message = "Install the lumberjack_rails gem for full support of the tagged method."
      Utils.deprecated("Logger#tagged", deprecation_message) do
        append_to(:tagged, *tags, &block)
      end
    end

    # Alias for clear_attributes.
    #
    # @see clear_attributes
    # @deprecated Use clear_attributes instead.
    def untagged(&block)
      Utils.deprecated("Logger#untagged", "Lumberjack::Logger#untagged is deprecated and will be removed in version 2.1; use clear_attributes instead.") do
        clear_attributes(&block)
      end
    end

    # Alias for with_level for compatibility with ActiveSupport loggers. This functionality
    # has been moved to the lumberjack_rails gem.
    #
    # @see with_level
    # @deprecated This implementation is deprecated. Install the lumberjack_rails gem for full support.
    def log_at(level, &block)
      deprecation_message = "Install the lumberjack_rails gem for full support of the log_at method."
      Utils.deprecated("Logger#log_at", deprecation_message) do
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
      Utils.deprecated("Logger#silence", deprecation_message) do
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
      return false if fiber_local&.logging

      severity = Severity.label_to_level(severity) unless severity.is_a?(Integer)

      fiber_locals do |locals|
        locals.logging = true # protection from infinite loops

        time = Time.now
        progname ||= self.progname
        attributes = nil unless attributes.is_a?(Hash)
        attributes = merge_attributes(merge_all_attributes, attributes)
        message, attributes = formatter.format(message, attributes) if formatter

        entry = Lumberjack::LogEntry.new(time, severity, message, progname, Process.pid, attributes)

        write_to_device(entry)
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

    def build_entry_formatter(formatter, message_formatter, attribute_formatter) # :nodoc:
      entry_formatter = formatter if formatter.is_a?(Lumberjack::EntryFormatter)

      unless entry_formatter
        message_formatter ||= formatter if formatter.is_a?(Lumberjack::Formatter) || formatter == :default
        entry_formatter = Lumberjack::EntryFormatter.new
      end

      message_formatter = Lumberjack::Formatter.default if message_formatter == :default

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
  end
end
