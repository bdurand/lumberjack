# frozen_string_literal: true

module Lumberjack
  class Device
    # A versatile logging device that writes formatted log entries to IO streams.
    # This device serves as the foundation for most output-based logging, converting
    # LogEntry objects into formatted strings using configurable templates and
    # writing them to any IO-compatible stream.
    #
    # The Writer device supports extensive customization through templates, encoding
    # options, stream management, and error handling. It can write to files, console
    # output, network streams, or any object that implements the IO interface.
    #
    # Templates can be either string-based (compiled into Template objects) or
    # callable objects (Procs, lambdas) for maximum flexibility. The device handles
    # character encoding, whitespace normalization, and provides robust error
    # recovery when stream operations fail.
    #
    # @example Basic file writing
    #   device = Lumberjack::Device::Writer.new(File.open("/var/log/app.log", "a"))
    #   logger = Lumberjack::Logger.new(device)
    #
    # @example Console output with custom template
    #   device = Lumberjack::Device::Writer.new(
    #     STDOUT,
    #     template: "[%{time}] %{severity}: %{message}"
    #   )
    #
    # @example Using a Proc template for custom formatting
    #   custom_formatter = ->(entry) do
    #     "#{entry.time.iso8601} | #{entry.severity_label.upcase} | #{entry.message}"
    #   end
    #   device = Lumberjack::Device::Writer.new(STDERR, template: custom_formatter)
    #
    # @see Template
    # @see Template::StandardFormatterTemplate
    class Writer < Device
      EDGE_WHITESPACE_PATTERN = /\A\s|[ \t\f\v][\r\n]*\z/

      # Initialize a new Writer device with configurable formatting and stream options.
      # The device supports multiple template types, encoding control, and stream
      # behavior configuration for flexible output handling.
      #
      # @param stream [IO, #write] The target stream for log output. Can be any object
      #   that responds to write(), including File objects, STDOUT/STDERR, StringIO,
      #   network streams, or custom IO-like objects
      # @param options [Hash] Configuration options for the writer device
      #
      # @option options [String, Proc, nil] :template The formatting template for log entries.
      #   - String: Compiled into a Template object (default: "[:time :severity :progname(:pid)] :message")
      #   - Proc: Called with LogEntry, should return formatted string
      #   - nil: Uses default template
      #
      # @option options [Logger::Formatter] :standard_logger_formatter Use a Ruby Logger
      #   formatter for compatibility with existing logging code
      #
      # @option options [String, nil] :additional_lines Template for formatting additional
      #   lines in multi-line messages (default: "\n  :message")
      #
      # @option options [String, Symbol] :time_format Format for timestamps in templates.
      #   Accepts strftime patterns or :milliseconds/:microseconds shortcuts
      #
      # @option options [String] :attribute_format Printf-style format for attributes
      #   with exactly two %s placeholders for name and value (default: "[%s:%s]")
      #
      # @option options [Boolean] :autoflush (true) Whether to automatically flush
      #   the stream after each write for immediate output
      #
      # @option options [Boolean] :binmode (false) Whether to treat the stream as
      #   binary, skipping UTF-8 encoding conversion
      def initialize(stream, options = {})
        @stream = stream
        @stream.sync = true if @stream.respond_to?(:sync=) && options[:autoflush] != false

        @binmode = options[:binmode]

        if options[:standard_logger_formatter]
          @template = Template::StandardFormatterTemplate.new(options[:standard_logger_formatter])
        else
          template = options[:template]
          @template = if template.respond_to?(:call)
            template
          else
            Template.new(template, additional_lines: options[:additional_lines], time_format: options[:time_format], attribute_format: options[:attribute_format])
          end
        end
      end

      # Write a log entry to the stream with automatic formatting and error handling.
      # The entry is converted to a string using the configured template, processed
      # for encoding and whitespace, and written to the stream with robust error recovery.
      #
      # @param entry [LogEntry, String] The log entry to write. LogEntry objects are
      #   formatted using the template, while strings are written directly after
      #   encoding and whitespace processing
      # @return [void]
      def write(entry)
        string = (entry.is_a?(LogEntry) ? @template.call(entry) : entry)
        return if string.nil?

        if !@binmode && string.encoding != Encoding::UTF_8
          string = string.encode("UTF-8", invalid: :replace, undef: :replace)
        end

        string = string.strip if string.match?(EDGE_WHITESPACE_PATTERN)
        return if string.length == 0 || string == Lumberjack::LINE_SEPARATOR

        write_to_stream(string)
      end

      # Close the underlying stream and release any associated resources. This method
      # ensures all buffered data is flushed before closing the stream, providing
      # clean shutdown behavior for file handles and network connections.
      #
      # @return [void]
      def close
        flush
        stream.close
      end

      # Flush the underlying stream to ensure all buffered data is written to the
      # destination. This method is safe to call on streams that don't support
      # flushing, making it suitable for various IO types.
      #
      # @return [void]
      def flush
        stream.flush if stream.respond_to?(:flush)
      end

      # Get the current datetime format from the template if supported. Returns the
      # format string used for timestamp formatting in log entries.
      #
      # @return [String, nil] The datetime format string if the template supports it,
      #   or nil if the template doesn't provide datetime formatting
      def datetime_format
        @template.datetime_format if @template.respond_to?(:datetime_format)
      end

      # Set the datetime format on the template if supported. This allows dynamic
      # reconfiguration of timestamp formatting without recreating the device.
      #
      # @param format [String] The datetime format string (strftime pattern) to
      #   apply to the template for timestamp formatting
      # @return [void]
      def datetime_format=(format)
        if @template.respond_to?(:datetime_format=)
          @template.datetime_format = format
        end
      end

      # Access the underlying IO stream for direct manipulation or compatibility
      # with code expecting Logger device interface. This method provides the
      # raw stream object for advanced use cases.
      #
      # @return [IO] The underlying stream object used for output
      def dev
        stream
      end

      # Get the file system path of the underlying stream if available. This method
      # is useful for monitoring, log rotation, or any operations that need to
      # work with the actual file path.
      #
      # @return [String, nil] The file system path if the stream is file-based,
      #   or nil for non-file streams (STDOUT, StringIO, network streams, etc.)
      def path
        stream.path if stream.respond_to?(:path)
      end

      protected

      # Set the underlying stream. This protected method allows subclasses to
      # change the output destination, which is useful for log rotation or
      # stream redirection scenarios.
      #
      # @param stream [IO] The new stream to use for output
      # @return [void]
      attr_writer :stream

      # Access the underlying stream for subclass operations. This protected
      # method provides stream access for inheritance patterns while maintaining
      # encapsulation.
      #
      # @return [IO] The current stream object
      attr_reader :stream

      private

      # Write a formatted line to the stream with robust error handling. This method
      # ensures proper line termination, handles IO errors gracefully, and provides
      # fallback error reporting to STDERR when the primary stream fails.
      #
      # @param line [String] The formatted log line to write
      # @return [void]
      def write_to_stream(line)
        out = line.end_with?(Lumberjack::LINE_SEPARATOR) ? line : "#{line}#{Lumberjack::LINE_SEPARATOR}"
        begin
          begin
            stream.write(out)
          rescue IOError => e
            raise e if stream.closed?

            stream.write(out)
          end
        rescue => e
          $stderr.write(error_message(e))
          $stderr.write(out)
        end
      end

      # Generate a detailed error message for logging failures. This method creates
      # informative error messages that include exception details and backtrace
      # information for debugging stream write failures.
      #
      # @param e [Exception] The exception that occurred during stream operations
      # @return [String] A formatted error message with exception details
      def error_message(e)
        "#{e.class.name}: #{e.message}#{" at " + e.backtrace.first if e.backtrace}#{Lumberjack::LINE_SEPARATOR}"
      end
    end
  end
end
