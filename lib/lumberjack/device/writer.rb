# frozen_string_literal: true

module Lumberjack
  class Device
    # This logging device writes log entries as strings to an IO stream. Output is written as a string
    # formatted by the template passed in.
    class Writer < Device
      DEFAULT_FIRST_LINE_TEMPLATE = "[:time :severity :progname(:pid)] :message :tags"
      DEFAULT_ADDITIONAL_LINES_TEMPLATE = "#{Lumberjack::LINE_SEPARATOR}> :message"

      # Create a new device to write log entries to a stream. Entries are converted to strings
      # using a Template. The template can be specified using the :template option. This can
      # either be a Proc or a string that will compile into a Template object.
      #
      # If the template is a Proc, it should accept an LogEntry as its only argument and output a string.
      #
      # If the template is a template string, it will be used to create a Template. The
      # :additional_lines and :time_format options will be passed through to the
      # Template constuctor.
      #
      # The default template is "[:time :severity :progname(:pid)] :message"
      # with additional lines formatted as "\n  :message".
      #
      # @param [IO] stream The stream to write log entries to.
      # @param [Hash] options The options for the device.
      def initialize(stream, options = {})
        @stream = stream
        @stream.sync = true if @stream.respond_to?(:sync=)

        @binmode = options[:binmode]

        if options[:standard_logger_formatter]
          @template = Template::StandardFormatterTemplate.new(options[:standard_logger_formatter])
        else
          template = options[:template] || DEFAULT_FIRST_LINE_TEMPLATE
          if template.respond_to?(:call)
            @template = template
          else
            additional_lines = options[:additional_lines] || DEFAULT_ADDITIONAL_LINES_TEMPLATE
            @template = Template.new(template, additional_lines: additional_lines, time_format: options[:time_format])
          end
        end
      end

      # Write an entry to the stream. The entry will be converted into a string using the defined template.
      #
      # @param [LogEntry, String] entry The entry to write to the stream.
      # @return [void]
      def write(entry)
        string = (entry.is_a?(LogEntry) ? @template.call(entry) : entry)
        return if string.nil?

        if !@binmode && string.encoding != Encoding::UTF_8
          string = string.encode("UTF-8", invalid: :replace, undef: :replace)
        end

        string = string.strip
        return if string.length == 0

        write_to_stream(string)
      end

      # Close the underlying stream.
      #
      # @return [void]
      def close
        flush
        stream.close
      end

      # Flush the underlying stream.
      #
      # @return [void]
      def flush
        stream.flush if stream.respond_to?(:flush)
      end

      # Get the datetime format.
      #
      # @return [String] The datetime format.
      def datetime_format
        @template.datetime_format if @template.respond_to?(:datetime_format)
      end

      # Set the datetime format.
      #
      # @param [String] format The datetime format.
      # @return [void]
      def datetime_format=(format)
        if @template.respond_to?(:datetime_format=)
          @template.datetime_format = format
        end
      end

      # Return the underlying stream. Provided for API compatibility with Logger devices.
      #
      # @return [IO] The underlying stream.
      def dev
        @stream
      end

      protected

      # Set the underlying stream.
      attr_writer :stream

      # Get the underlying stream.
      attr_reader :stream

      private

      def write_to_stream(line)
        out = "#{line}#{Lumberjack::LINE_SEPARATOR}"
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

      def error_message(e)
        "#{e.class.name}: #{e.message}#{" at " + e.backtrace.first if e.backtrace}#{Lumberjack::LINE_SEPARATOR}"
      end
    end
  end
end
