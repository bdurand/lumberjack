# frozen_string_literal: true

module Lumberjack
  # Logger is a thread safe implementation of the standard library Logger class. TODO: update this
  #
  # === Example
  #
  #   logger = Lumberjack::Logger.new
  #   logger.info("Starting processing")
  #   logger.debug("Processing options #{options.inspect}")
  #   logger.fatal("OMG the application is on fire!")
  #
  # Log entries are written to a logging Device if their severity meets or exceeds the log level.
  #
  # Devices may use buffers internally and the log entries are not guaranteed to be written until you call
  # the +flush+ method. Sometimes this can result in problems when trying to track down extraordinarily
  # long running sections of code since it is likely that none of the messages logged before the long
  # running code will appear in the log until the entire process finishes. You can set the +:flush_seconds+
  # option on the constructor to force the device to be flushed periodically. This will create a new
  # monitoring thread, but its use is highly recommended.
  #
  # Each log entry records the log message and severity along with the time it was logged, the
  # program name, process id, and an optional hash of tags. The message will be converted to a string, but
  # otherwise, it is up to the device how these values are recorded. Messages are converted to strings
  # using a Formatter associated with the logger.
  class Logger < ::Logger
    include ContextLogger

    # The time that the device was last flushed.
    attr_reader :last_flushed_at

    attr_accessor :formatter

    # Create a new logger to log to a Device.
    #
    # The +device+ argument can be in any one of several formats.
    #
    # If it is a Device object, that object will be used.
    # If it has a +write+ method, it will be wrapped in a Device::Writer class.
    # If it is :null, it will be a Null device that won't record any output.
    # Otherwise, it will be assumed to be file path and wrapped in a Device::LogFile class.
    #
    # All other options are passed to the device constuctor.
    #
    # @param [Lumberjack::Device, Object, Symbol, String] device The device to log to.
    # @param [Hash] options The options for the logger.
    # @option options [Integer, Symbol, String] :level The logging level below which messages will be ignored.
    # @option options [Lumberjack::Formatter] :formatter The formatter to use for outputting messages to the log.
    # @option options [String] :datetime_format The format to use for log timestamps.
    # @option options [Lumberjack::Formatter] :message_formatter The MessageFormatter to use for formatting log messages.
    # @option options [Lumberjack::TagFormatter] :tag_formatter The TagFormatter to use for formatting tags.
    # @option options [String] :progname The name of the program that will be recorded with each log entry.
    # @option options [Numeric] :flush_seconds The maximum number of seconds between flush calls.
    # @option options [Boolean] :roll If the log device is a file path, it will be a Device::DateRollingLogFile if this is set.
    # @option options [Integer] :max_size If the log device is a file path, it will be a Device::SizeRollingLogFile if this is set.
    def initialize(logdev, shift_age = 0, shift_size = 1048576,
      level: DEBUG, progname: nil, formatter: nil, datetime_format: nil,
      binmode: false, shift_period_suffix: "%Y%m%d", reraise_write_errors: [], skip_header: false,
      message_formatter: nil, tag_formatter: nil, flush_seconds: nil, buffer_size: 0, template: nil)
      init_fiber_locals!

      @logdev = open_device(logdev,
        datetime_format: datetime_format,
        binmode: binmode,
        shift_period_suffix: shift_period_suffix,
        reraise_write_errors: reraise_write_errors,
        skip_header: skip_header,
        buffer_size: buffer_size,
        template: template)

      @context = Context.new
      self.level = level || DEBUG
      self.progname = progname

      entry_formatter = formatter if formatter.is_a?(Lumberjack::EntryFormatter)
      unless entry_formatter
        message_formatter ||= formatter if formatter.is_a?(Lumberjack::Formatter)
        entry_formatter = Lumberjack::EntryFormatter.new
      end
      entry_formatter.message_formatter = message_formatter if message_formatter
      entry_formatter.tag_formatter = tag_formatter if tag_formatter

      self.formatter = entry_formatter
      self.datetime_format = datetime_format if datetime_format

      @closed = false # TODO

      @last_flushed_at = Time.now
      create_flusher_thread(flush_seconds.to_f) if flush_seconds.to_f > 0
    end

    # Get the logging device that is used to write log entries.
    #
    # @return [Lumberjack::Device] The logging device.
    def device
      @logdev
    end

    # Set the logging device to a new device.
    #
    # @param [Lumberjack::Device] device The new logging device.
    # @return [void]
    def device=(device)
      @logdev = device.nil? ? nil : open_device(device, {})
    end

    # Get the timestamp format on the device if it has one.
    #
    # @return [String, nil] The timestamp format or nil if the device doesn't support it.
    def datetime_format
      device.datetime_format if device.respond_to?(:datetime_format)
    end

    # Set the timestamp format on the device if it is supported.
    #
    # @param [String] format The timestamp format.
    # @return [void]
    def datetime_format=(format)
      if device.respond_to?(:datetime_format=)
        device.datetime_format = format
      end
    end

    def message_formatter
      formatter.message_formatter
    end

    def message_formatter=(value)
      formatter.message_formatter = value
    end

    def tag_formatter
      formatter.tags.tag_formatter
    end

    def tag_formatter=(value)
      formatter.tag_formatter = value
    end

    # Flush the logging device. Messages are not guaranteed to be written until this method is called.
    #
    # @return [void]
    def flush
      device.flush
      @last_flushed_at = Time.now
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
    # @param [Object] logdev passed through to the logging device.
    def reopen(logdev = nil)
      @closed = false
      device.reopen(logdev) if device.respond_to?(:reopen)
    end

    # Set the program name that is associated with log messages. If a block
    # is given, the program name will be valid only within the block.
    #
    # @param [String] value The program name to use.
    # @return [void]
    def set_progname(value, &block)
      if block
        with_progname(value, &block)
      else
        self.progname = value
      end
    end

    alias_method :tag_globally, :tag!

    alias_method :in_tag_context?, :in_context?

    # Add an entry to the log.
    #
    # @param [Integer, Symbol, String] severity The severity of the message.
    # @param [Object] message The message to log.
    # @param [String] progname The name of the program that is logging the message.
    # @param [Hash] tags The tags to add to the log entry.
    # @return [void]
    # @api private
    #
    # @example
    #
    #   logger.add_entry(Logger::ERROR, exception)
    #   logger.add_entry(Logger::INFO, "Request completed")
    #   logger.add_entry(:warn, "Request took a long time")
    #   logger.add_entry(Logger::DEBUG){"Start processing with options #{options.inspect}"}
    def add_entry(severity, message, progname = nil, tags = nil)
      severity = Severity.label_to_level(severity) unless severity.is_a?(Integer)
      return true unless device && severity && severity >= level
      return true if fiber_local_value(:logging)

      begin
        set_fiber_local_value(:logging, true) # protection from infinite loops

        time = Time.now
        progname ||= self.progname
        tags = nil unless tags.is_a?(Hash)
        tags = merge_tags(self.tags, tags)
        message, tags = formatter.format(message, tags) if formatter

        entry = Lumberjack::LogEntry.new(time, severity, message, progname, Process.pid, tags)

        write_to_device(entry)
      ensure
        set_fiber_local_value(:logging, nil)
      end
      true
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
      if device.nil?
        nil
      elsif device.is_a?(Device)
        device
      elsif device.respond_to?(:write) && device.respond_to?(:flush)
        Device::Writer.new(device, options)
      elsif device == :null
        Device::Null.new
      else
        device = device.to_s
        if options[:roll]
          Device::DateRollingLogFile.new(device, options)
        elsif options[:max_size]
          Device::SizeRollingLogFile.new(device, options)
        else
          Device::LogFile.new(device, options)
        end
      end
    end

    # Create a thread that will periodically call flush.
    def create_flusher_thread(flush_seconds) # :nodoc:
      if flush_seconds > 0
        begin
          logger = self
          Thread.new do
            until closed?
              begin
                sleep(flush_seconds)
                logger.flush if Time.now - logger.last_flushed_at >= flush_seconds
              rescue => e
                warn("Error flushing log: #{e.inspect}")
              end
            end
          end
        end
      end
    end
  end
end
