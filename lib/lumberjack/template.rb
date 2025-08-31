# frozen_string_literal: true

module Lumberjack
  # A flexible template system for converting log entries into formatted strings.
  # Templates use placeholder substitution to create customizable log output formats
  # with support for all log entry components and custom attributes.
  #
  # The template system supports the following built-in placeholders:
  # * `:time` - The log entry timestamp
  # * `:severity` - The severity level (DEBUG, INFO, WARN, ERROR, FATAL)
  # * `:progname` - The program name that generated the entry
  # * `:pid` - The process ID
  # * `:message` - The main log message content
  # * `:attributes` - All custom attributes formatted as key:value pairs
  #
  # Custom attribute placeholders can be created using `:attribute_name` syntax.
  # For attribute names containing special characters, use curly bracket notation:
  # `:{ http.request-id }` or `:{ user-agent }`.
  #
  # The `:tag` placeholder is supported for backward compatibility with version 1.x
  # and functions identically to `:attributes`.
  #
  # @example Basic template usage
  #   template = Lumberjack::Template.new("[:time :severity] :message")
  #   # Output: [2023-08-21T10:30:15.123 INFO] User logged in
  #
  # @example Template with custom attributes
  #   template = Lumberjack::Template.new("[:time :severity :user_id] :message")
  #   # Output: [2023-08-21T10:30:15.123 INFO 12345] User action completed
  #
  # @example Multi-line message formatting
  #   template = Lumberjack::Template.new(
  #     "[:time :severity] :message",
  #     additional_lines: "\n    | :message"
  #   )
  #   # Output:
  #   # [2023-08-21T10:30:15.123 INFO] First line
  #   #     | Second line
  #   #     | Third line
  #
  # @example Custom time formatting
  #   template = Lumberjack::Template.new(
  #     "[:time :severity] :message",
  #     time_format: "%Y-%m-%d %H:%M:%S"
  #   )
  #   # Output: [2023-08-21 10:30:15 INFO] Message content
  class Template
    DEFAULT_FIRST_LINE_TEMPLATE = "[:time :severity :progname(:pid)] :message :attributes"
    DEFAULT_ADDITIONAL_LINES_TEMPLATE = "#{Lumberjack::LINE_SEPARATOR}> :message"
    DEFAULT_ATTRIBUTE_FORMAT = "[%s:%s]"

    # A wrapper template that delegates formatting to a standard Ruby Logger formatter.
    # This provides compatibility with existing Logger::Formatter implementations while
    # maintaining the Template interface for consistent usage within Lumberjack.
    class StandardFormatterTemplate < Template
      # Create a new wrapper for a standard Ruby Logger formatter.
      #
      # @param formatter [Logger::Formatter] The formatter to wrap
      def initialize(formatter, pad_severity: false)
        @formatter = formatter
        @pad_severity = pad_severity
      end

      # Format a log entry using the wrapped formatter.
      #
      # @param entry [Lumberjack::LogEntry] The log entry to format
      # @return [String] The formatted log entry
      def call(entry)
        @formatter.call(entry.severity_label(@pad_severity), entry.time, entry.progname, entry.message)
      end

      # Set the datetime format on the wrapped formatter if supported.
      #
      # @param value [String] The datetime format string
      # @return [void]
      def datetime_format=(value)
        @formatter.datetime_format = value if @formatter.respond_to?(:datetime_format=)
      end

      # Get the datetime format from the wrapped formatter if supported.
      #
      # @return [String, nil] The datetime format string, or nil if not supported
      def datetime_format
        @formatter.datetime_format if @formatter.respond_to?(:datetime_format)
      end
    end

    TEMPLATE_ARGUMENT_ORDER = %w[:time :severity :progname :pid :message :attributes].freeze
    MILLISECOND_TIME_FORMAT = "%Y-%m-%dT%H:%M:%S.%3N"
    MICROSECOND_TIME_FORMAT = "%Y-%m-%dT%H:%M:%S.%6N"
    PLACEHOLDER_PATTERN = /:(([a-z0-9_]+)|({[^}]+}))/i
    private_constant :TEMPLATE_ARGUMENT_ORDER, :MILLISECOND_TIME_FORMAT, :MICROSECOND_TIME_FORMAT, :PLACEHOLDER_PATTERN

    # Create a new template with customizable formatting options. The template
    # supports different formatting for single-line and multi-line messages,
    # custom time formatting, and configurable attribute display.
    #
    # @param first_line [String] Template for formatting the first line of messages.
    #   Defaults to "[:time :severity :progname(:pid)] :message :attributes"
    # @param additional_lines [String, nil] Template for formatting additional lines
    #   in multi-line messages. Defaults to "\n> :message"
    # @param time_format [String, Symbol, nil] Time formatting specification. Can be:
    #   - A strftime format string (e.g., "%Y-%m-%d %H:%M:%S")
    #   - `:milliseconds` for ISO format with millisecond precision (default)
    #   - `:microseconds` for ISO format with microsecond precision
    # @param attribute_format [String, nil] Printf-style format for individual attributes.
    #   Must contain exactly two %s placeholders for name and value. Defaults to "[%s:%s]"
    # @param pad_severity [Boolean] Whether to pad the severity label to a fixed width.
    # @raise [ArgumentError] If attribute_format doesn't contain exactly two %s placeholders
    def initialize(first_line, additional_lines: nil, time_format: nil, attribute_format: nil, pad_severity: false)
      first_line ||= DEFAULT_FIRST_LINE_TEMPLATE
      @first_line_template, @first_line_attributes = compile("#{first_line.chomp}#{Lumberjack::LINE_SEPARATOR}")

      additional_lines ||= DEFAULT_ADDITIONAL_LINES_TEMPLATE
      @additional_line_template, @additional_line_attributes = compile(additional_lines)

      @attribute_template = attribute_format || DEFAULT_ATTRIBUTE_FORMAT
      unless @attribute_template.scan("%s").size == 2
        raise ArgumentError.new("attribute_format must be a printf template with exactly two '%s' placeholders")
      end

      # Formatting the time is relatively expensive, so only do it if it will be used
      @template_include_time = first_line.include?(":time") || additional_lines.include?(":time")
      self.datetime_format = (time_format || :milliseconds)

      @pad_severity = pad_severity
    end

    # Set the datetime format used for timestamp formatting in the template.
    # This method accepts both strftime format strings and symbolic shortcuts.
    #
    # @param format [String, Symbol] The datetime format specification:
    #   - String: A strftime format pattern (e.g., "%Y-%m-%d %H:%M:%S")
    #   - `:milliseconds`: ISO format with millisecond precision (YYYY-MM-DDTHH:MM:SS.sss)
    #   - `:microseconds`: ISO format with microsecond precision (YYYY-MM-DDTHH:MM:SS.ssssss)
    # @return [void]
    def datetime_format=(format)
      if format == :milliseconds
        format = MILLISECOND_TIME_FORMAT
      elsif format == :microseconds
        format = MICROSECOND_TIME_FORMAT
      end
      @time_formatter = Formatter::DateTimeFormatter.new(format)
    end

    # Get the current datetime format string used for timestamp formatting.
    #
    # @return [String] The strftime format string currently in use
    def datetime_format
      @time_formatter.format
    end

    # Convert a log entry into a formatted string using the template. This method
    # handles both single-line and multi-line messages, applying the appropriate
    # templates and performing placeholder substitution.
    #
    # @param entry [Lumberjack::LogEntry] The log entry to format
    # @return [String] The formatted log entry string
    def call(entry)
      return entry unless entry.is_a?(LogEntry)

      first_line = entry.message.to_s
      additional_lines = nil
      if first_line.include?(Lumberjack::LINE_SEPARATOR)
        additional_lines = first_line.split(Lumberjack::LINE_SEPARATOR)
        first_line = additional_lines.shift
      end

      formatted_time = @time_formatter.call(entry.time) if @template_include_time
      format_args = [formatted_time, entry.severity_label(@pad_severity), entry.progname, entry.pid, first_line]
      append_attribute_args!(format_args, entry.attributes, @first_line_attributes)
      message = (@first_line_template % format_args)

      if additional_lines && !additional_lines.empty?
        format_args.slice!(5, format_args.size)
        append_attribute_args!(format_args, entry.attributes, @additional_line_attributes)

        message_length = message.length
        message.chomp!(Lumberjack::LINE_SEPARATOR)
        chomped = message.length != message_length

        additional_lines.each do |line|
          format_args[4] = line
          line_message = @additional_line_template % format_args
          message << line_message
        end

        message << Lumberjack::LINE_SEPARATOR if chomped
      end
      message
    end

    private

    # Build the arguments array for sprintf formatting by appending attribute values.
    # This method handles both the general :attributes placeholder and specific
    # attribute placeholders defined in the template.
    #
    # @param args [Array] The existing format arguments array to modify
    # @param attributes [Hash, nil] The log entry attributes hash
    # @param attribute_vars [Array<String>] List of specific attribute names used in template
    # @return [void]
    def append_attribute_args!(args, attributes, attribute_vars)
      if attributes.nil? || attributes.size == 0
        (attribute_vars.length + 1).times { args << nil }
        return
      end

      attributes_string = +""
      attributes.each do |name, value|
        unless value.nil? || attribute_vars.include?(name)
          value = value.to_s
          value = value.gsub(Lumberjack::LINE_SEPARATOR, " ") if value.include?(Lumberjack::LINE_SEPARATOR)
          attributes_string << " "
          attributes_string << @attribute_template % [name, value]
        end
      end

      args << attributes_string
      attribute_vars.each do |name|
        args << attributes[name]
      end
    end

    # Parse and compile a template string into a sprintf-compatible format string
    # and extract attribute variable names. This method handles placeholder
    # substitution and escape sequence processing.
    #
    # @param template [String] The raw template string with placeholders
    # @return [Array<String, Array<String>>] A tuple of [compiled_template, attribute_vars]
    def compile(template) # :nodoc:
      template = template.gsub(/:({ *)?tags(?: *})?\b/, ":\\1attributes") unless template.include?(":attributes")
      template = template.gsub(/ :({ *)?attributes\b/, ":\\1attributes")
      template = template.gsub(/%(?!%)/, "%%")

      attribute_vars = []
      template = template.gsub(PLACEHOLDER_PATTERN) do |match|
        var_name = match.sub(/{ */, "").sub(/ *}/, "")
        position = TEMPLATE_ARGUMENT_ORDER.index(var_name)
        if position
          "%#{position + 1}$s"
        else
          attribute_vars << var_name[1, var_name.length]
          "%#{TEMPLATE_ARGUMENT_ORDER.size + attribute_vars.size}$s"
        end
      end
      [template, attribute_vars]
    end
  end
end
