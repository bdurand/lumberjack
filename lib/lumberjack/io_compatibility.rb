# frozen_string_literal: true

module Lumberjack
  # IOCompatibility provides methods that allow a logger to be used as an IO-like stream.
  # This enables loggers to be used anywhere an IO object is expected, such as for
  # redirecting standard output/error or integrating with libraries that expect stream objects.
  #
  # When used as a stream, all written values are logged with UNKNOWN severity and include
  # timestamps and other standard log entry metadata. This is particularly useful for:
  # - Capturing output from external libraries or subprocesses
  # - Redirecting STDOUT/STDERR to logs
  # - Providing a logging destination that conforms to IO interface expectations
  #
  # The module implements the essential IO methods like write, puts, print, printf, flush,
  # and close to provide broad compatibility with Ruby's IO ecosystem.
  #
  # @example Basic stream usage
  #   logger = Lumberjack::Logger.new(STDOUT)
  #   logger.puts("Hello, world!")  # Logs with UNKNOWN severity
  #   logger.write("Direct write")  # Also logs with UNKNOWN severity
  #
  # @example Setting the log entry severity
  #   logger = Lumberjack::Logger.new(STDOUT)
  #   logger.default_severity = :info
  #   logger.puts("This is an info message") # Logs with INFO severity
  #
  # @example Using as STDOUT replacement
  #   logger = Lumberjack::Logger.new("/var/log/app.log")
  #   $stdout = logger  # Redirect all puts/print calls to the logger
  #   puts "This goes to the log file"
  #
  # @example With external libraries
  #   logger = Lumberjack::Logger.new(STDOUT)
  #   some_library.run(output_stream: logger)  # Library writes to logger
  module IOCompatibility
    # Write a value to the log as a log entry. The value will be recorded with UNKNOWN severity,
    # ensuring it always appears in the log regardless of the current log level.
    #
    # @param value [Object] The message to write. Will be converted to a string for logging.
    # @return [Integer] Returns 1 if a log entry was written, or 0 if the value was nil or empty.
    def write(value)
      return 0 if value.nil? || value == ""

      self << value
      1
    end

    # Write multiple values to the log, each as a separate log entry with UNKNOWN severity.
    # This method mimics the behavior of IO#puts by writing each argument on a separate line.
    #
    # @param args [Array<Object>] The messages to write. Each will be converted to a string.
    # @return [nil]
    def puts(*args)
      args.each do |arg|
        write(arg)
      end
      nil
    end

    # Concatentate strings into a single log entry. This mimics IO#print behavior
    # by writing arguments without separators. If no arguments are given, writes the
    # value of the global $_ variable.
    #
    # @param args [Array<Object>] The messages to write. If empty, uses $_ (last input record).
    # @return [nil]
    #
    # @example
    #   logger.print("Hello", " ", "World")  # Single log entry: "Hello World"
    def print(*args)
      if args.empty?
        write($_)
      else
        write(args.join(""))
      end
      nil
    end

    # Write a formatted string to the log using sprintf-style formatting. The formatted
    # result is logged as a single entry with UNKNOWN severity.
    #
    # @param format [String] The format string (printf-style format specifiers).
    # @param args [Array<Object>] The values to substitute into the format string.
    # @return [nil]
    #
    # @example
    #   logger.printf("User %s logged in at %s", "alice", Time.now)
    #   # Logs: "User alice logged in at 2025-08-21 10:30:00 UTC"
    def printf(format, *args)
      write(format % args)
      nil
    end

    # Flush any buffered output. This method is provided for IO compatibility but
    # is a no-op since log entries are typically written immediately to the underlying device.
    # The actual flushing behavior depends on the logging device being used.
    #
    # @return [nil]
    def flush
    end

    # Close the stream. This method is provided for IO compatibility but is a no-op.
    # To actually close a logger, call close on the logger object itself, which will
    # close the underlying logging device.
    #
    # @return [nil]
    def close
    end

    # Check if the stream is closed. Always returns false since loggers using this
    # module don't maintain a closed state through this interface.
    #
    # @return [Boolean] Always returns false.
    def closed?
      false
    end

    # Check if the stream is connected to a terminal (TTY). Always returns false
    # since loggers are not terminal devices, even when they write to STDOUT/STDERR.
    # This method is required for complete IO compatibility.
    #
    # @return [Boolean] Always returns false.
    # @api private
    def tty?
      false
    end

    # Set the encoding for the stream. This method is provided for IO compatibility
    # but is a no-op since loggers handle encoding internally through their devices
    # and formatters.
    #
    # @param _encoding [String, Encoding] The encoding to set (ignored).
    # @return [nil]
    # @api private
    def set_encoding(_encoding)
    end
  end
end
