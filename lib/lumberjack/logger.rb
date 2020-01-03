# frozen_string_literals: true

module Lumberjack
  # Logger is a thread safe logging object. It has a compatible API with the Ruby
  # standard library Logger class, the Log4r gem, and ActiveSupport::BufferedLogger.
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
  # program name, process id, and unit of work id. The message will be converted to a string, but
  # otherwise, it is up to the device how these values are recorded. Messages are converted to strings
  # using a Formatter associated with the logger.
  class Logger < ::Logger
    # include Severity

    # The time that the device was last flushed.
    attr_reader :last_flushed_at

    # Set +silencer+ to false to disable silencing the log.
    attr_accessor :silencer

    # Create a new logger to log to a Device.
    #
    # The +device+ argument can be in any one of several formats.
    #
    # If it is a Device object, that object will be used.
    # If it has a +write+ method, it will be wrapped in a Device::Writer class.
    # If it is <tt>:null</tt>, it will be a Null device that won't record any output.
    # Otherwise, it will be assumed to be file path and wrapped in a Device::LogFile class.
    #
    # This method can take the following options:
    #
    # * <tt>:level</tt> - The logging level below which messages will be ignored.
    # * <tt>:formatter</tt> - The formatter to use for outputting messages to the log.
    # * <tt>:datetime_format</tt> - The format to use for log timestamps.
    # * <tt>:progname</tt> - The name of the program that will be recorded with each log entry.
    # * <tt>:flush_seconds</tt> - The maximum number of seconds between flush calls.
    # * <tt>:roll</tt> - If the log device is a file path, it will be a Device::DateRollingLogFile if this is set.
    # * <tt>:max_size</tt> - If the log device is a file path, it will be a Device::SizeRollingLogFile if this is set.
    #
    # All other options are passed to the device constuctor.
    def initialize(device = STDOUT, options = {})
      options = options.dup
      self.level = options.delete(:level) || INFO
      self.progname = options.delete(:progname)
      max_flush_seconds = options.delete(:flush_seconds).to_f

      @logdev = open_device(device, options) if device
      @formatter = (options[:formatter] || Formatter.new)
      self.datetime_format = options[:datetime_format] if options[:datetime_format]
      @last_flushed_at = Time.now
      @silencer = true
      @tags = {}

      create_flusher_thread(max_flush_seconds) if max_flush_seconds > 0
    end

    # Get the timestamp format on the device if it has one.
    def datetime_format
      @logdev.datetime_format if @logdev.respond_to?(:datetime_format)
    end

    # Set the timestamp format on the device if it is supported.
    def datetime_format=(format)
      if @logdev.respond_to?(:datetime_format=)
        @logdev.datetime_format = format
      end
    end

    # Get the level of severity of entries that are logged. Entries with a lower
    # severity level will be ignored.
    def level
      thread_local_value(:lumberjack_logger_level) || @level
    end

    # Add a message to the log with a given severity. The message can be either
    # passed in the +message+ argument or supplied with a block. This method
    # is not normally called. Instead call one of the helper functions
    # +fatal+, +error+, +warn+, +info+, or +debug+.
    #
    # The severity can be passed in either as one of the Severity constants,
    # or as a Severity label.
    #
    # === Example
    #
    #   logger.add(Logger::ERROR, exception)
    #   logger.add(Logger::INFO, "Request completed")
    #   logger.add(:warn, "Request took a long time")
    #   logger.add(Logger::DEBUG){"Start processing with options #{options.inspect}"}
    def add(severity, message = nil, progname = nil, tags = nil)
      severity = Severity.label_to_level(severity) unless severity.is_a?(Integer)

      return true unless @logdev && severity && severity >= level

      time = Time.now
      if message.nil?
        if block_given?
          message = yield
        else
          message = progname
          progname = nil
        end
      end

      message = formatter.format(message)
      progname ||= self.progname
      current_tags = self.tags
      if current_tags.empty?
        tags = Tags.stringify_keys(tags) unless tags.nil?
      else
        if tags.nil?
          tags = current_tags.dup
        else
          tags = current_tags.merge(Tags.stringify_keys(tags))
        end
      end

      entry = LogEntry.new(time, severity, message, progname, $$, tags)
      write_to_device(entry)
      
      true
    end

    alias_method :log, :add

    # Flush the logging device. Messages are not guaranteed to be written until this method is called.
    def flush
      device.flush
      @last_flushed_at = Time.now
      nil
    end

    # The device being written to.
    def device
      @logdev
    end

    # Close the logging device.
    def close
      flush
      @logdev.close if @logdev.respond_to?(:close)
    end

    # Log a +FATAL+ message. The message can be passed in either the +message+ argument or in a block.
    def fatal(message_or_progname = nil, tags = nil, &block)
      add(FATAL, nil, message_or_progname, tags, &block)
    end

    # Return +true+ if +FATAL+ messages are being logged.
    def fatal?
      level <= FATAL
    end

    # Log an +ERROR+ message. The message can be passed in either the +message+ argument or in a block.
    def error(message_or_progname = nil, tags = nil, &block)
      add(ERROR, nil, message_or_progname, tags, &block)
    end

    # Return +true+ if +ERROR+ messages are being logged.
    def error?
      level <= ERROR
    end

    # Log a +WARN+ message. The message can be passed in either the +message+ argument or in a block.
    def warn(message_or_progname = nil, tags = nil, &block)
      add(WARN, nil, message_or_progname, tags, &block)
    end

    # Return +true+ if +WARN+ messages are being logged.
    def warn?
      level <= WARN
    end

    # Log an +INFO+ message. The message can be passed in either the +message+ argument or in a block.
    def info(message_or_progname = nil, tags = nil, &block)
      add(INFO, nil, message_or_progname, tags, &block)
    end

    # Return +true+ if +INFO+ messages are being logged.
    def info?
      level <= INFO
    end

    # Log a +DEBUG+ message. The message can be passed in either the +message+ argument or in a block.
    def debug(message_or_progname = nil, tags = nil, &block)
      add(DEBUG, nil, message_or_progname, tags, &block)
    end

    # Return +true+ if +DEBUG+ messages are being logged.
    def debug?
      level <= DEBUG
    end

    # Log a +TRACE+ message. The message can be passed in either the +message+ argument or in a block.
    def trace(message_or_progname = nil, tags = nil, &block)
      add(TRACE, nil, message_or_progname, tags, &block)
    end

    # Return +true+ if +TRACE+ messages are being logged.
    def trace?
      level <= TRACE
    end

    # Log a message when the severity is not known. Unknown messages will always appear in the log.
    # The message can be passed in either the +message+ argument or in a block.
    def unknown(message_or_progname = nil, tags = nil, &block)
      add(UNKNOWN, nil, message_or_progname, tags, &block)
    end

    def <<(msg)
      add(UNKNOWN, nil, msg, nil)
    end

    # Silence the logger by setting a new log level inside a block. By default, only +ERROR+ or +FATAL+
    # messages will be logged.
    #
    # === Example
    #
    #   logger.level = Logger::INFO
    #   logger.silence do
    #     do_something   # Log level inside the block is +ERROR+
    #   end
    def silence(temporary_level = ERROR, &block)
      if silencer
        push_thread_local_value(:lumberjack_logger_level, temporary_level, &block)
      else
        yield
      end
    end

    # Set the program name that is associated with log messages. If a block
    # is given, the program name will be valid only within the block.
    def set_progname(value, &block)
      if block
        push_thread_local_value(:lumberjack_logger_progname, value, &block)
      else
        self.progname = value
      end
    end

    # Get the program name associated with log messages.
    def progname
      thread_local_value(:lumberjack_logger_progname) || @progname
    end

    # Set a hash of tags on logger. If a block is given, the tags will only be set
    # for the duration of the block.
    def tag(tags, &block)
      tags = Tags.stringify_keys(tags)
      if block
        thread_tags = thread_local_value(:lumberjack_logger_tags)
        value = (thread_tags ? thread_tags.merge(tags) : tags)
        push_thread_local_value(:lumberjack_logger_tags, value, &block)
      else
        @tags.merge!(tags)
      end
    end

    # Return all tags in scope on the logger including global tags set on the Lumberjack
    # context, tags set on the logger, and tags set on the current block for the logger
    def tags
      tags = {}
      context_tags = Lumberjack.context_tags
      tags.merge!(context_tags) if context_tags && !context_tags.empty?
      tags.merge!(@tags) if !@tags.empty?
      scope_tags = thread_local_value(:lumberjack_logger_tags)
      tags.merge!(scope_tags) if scope_tags && !scope_tags.empty?
      tags
    end

    private

    # Set a local value for a thread tied to this object.
    def set_thread_local_value(name, value) #:nodoc:
      values = Thread.current[name]
      unless values
        values = {}
        Thread.current[name] = values
      end
      if value.nil?
        values.delete(self)
        Thread.current[name] = nil if values.empty?
      else
        values[self] = value
      end
    end

    # Get a local value for a thread tied to this object.
    def thread_local_value(name) #:nodoc:
      values = Thread.current[name]
      values[self] if values
    end

    # Set a local value for a thread tied to this object within a block.
    def push_thread_local_value(name, value) #:nodoc:
      save_val = thread_local_value(name)
      set_thread_local_value(name, value)
      begin
        yield
      ensure
        set_thread_local_value(name, save_val)
      end
    end

    # Open a logging device.
    def open_device(device, options) #:nodoc:
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

    def write_to_device(entry) #:nodoc:
      begin
        @logdev.write(entry)
      rescue => e
        $stderr.puts("#{e.class.name}: #{e.message}#{' at ' + e.backtrace.first if e.backtrace}")
        $stderr.puts(entry.to_s)
      end
    end
    
    # Create a thread that will periodically call flush.
    def create_flusher_thread(flush_seconds) #:nodoc:
      if flush_seconds > 0
        begin
          logger = self
          Thread.new do
            loop do
              begin
                sleep(flush_seconds)
                logger.flush if Time.now - logger.last_flushed_at >= flush_seconds
              rescue => e
                STDERR.puts("Error flushing log: #{e.inspect}")
              end
            end
          end
        end
      end
    end
  end
end
