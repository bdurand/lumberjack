# frozen_string_literal: true

module Lumberjack
  # A flexible template system for converting log entries into formatted strings.
  # Templates use mustache style placeholders to create customizable log output formats.
  #
  # The template system supports the following built-in placeholders:
  #
  # - <code>{{time}}</code> - The log entry timestamp
  # - <code>{{severity}}</code> - The severity level (DEBUG, INFO, WARN, ERROR, FATAL). The severity
  #   can also be formatted in a variety of ways with an optional format specifier.
  #   Supported formats include:
  #   - <code>{{severity(padded)}}</code> - Right padded so that all values are five characters
  #   - <code>{{severity(char)}}</code> - Single character representation (D, I, W, E, F)
  #   - <code>{{severity(emoji)}}</code> - Emoji representation
  #   - <code>{{severity(level)}}</code> - Numeric level representation
  # - <code>{{progname}}</code> - The program name that generated the entry
  # - <code>{{pid}}</code> - The process ID
  # - <code>{{message}}</code> - The main log message content
  # - <code>{{attributes}}</code> - All custom attributes formatted as key:value pairs
  #
  # Custom attribute placeholders can also be put in the double bracket placeholders.
  # Any attributes explicitly added to the template in their own placeholder will be removed
  # from the general list of attributes.
  #
  # @example Basic template usage
  #   template = Lumberjack::Template.new("[{{time}} {{severity}}] {{message}}")
  #   # Output: [2023-08-21T10:30:15.123 INFO] User logged in
  #
  # @example Multi-line message formatting
  #   template = Lumberjack::Template.new(
  #     "[{{time}} {{severity}}] {{message}}",
  #     additional_lines: "\n    | {{message}}"
  #   )
  #   # Output:
  #   # [2023-08-21T10:30:15.123 INFO] First line
  #   #     | Second line
  #   #     | Third line
  #
  # @example Custom attribute placeholders
  #   # The user_id attribute will be put before the message instead of with the rest of the attributes.
  #   template = Lumberjack::Template.new("[{{time}} {{severity}}] (usr:{{user_id}} {{message}} -- {{attributes}})")
  class Template
    DEFAULT_FIRST_LINE_TEMPLATE = "[{{time}} {{severity(padded)}} {{progname}}({{pid}})] {{message}} {{attributes}}"
    STDLIB_FIRST_LINE_TEMPLATE = "{{severity(char)}}, [{{time}} {{pid}}] {{severity(padded)}} -- {{progname}}: {{message}} {{attributes}}"
    DEFAULT_ADDITIONAL_LINES_TEMPLATE = "#{Lumberjack::LINE_SEPARATOR}> {{message}}"
    DEFAULT_ATTRIBUTE_FORMAT = "[%s:%s]"

    TemplateRegistry.add(:default, DEFAULT_FIRST_LINE_TEMPLATE)
    TemplateRegistry.add(:stdlib, STDLIB_FIRST_LINE_TEMPLATE)

    # A wrapper template that delegates formatting to a standard Ruby Logger formatter.
    # This provides compatibility with existing Logger::Formatter implementations while
    # maintaining the Template interface for consistent usage within Lumberjack.
    class StandardFormatterTemplate < Template
      # Create a new wrapper for a standard Ruby Logger formatter.
      #
      # @param formatter [Logger::Formatter] The formatter to wrap
      def initialize(formatter)
        @formatter = formatter
      end

      # Format a log entry using the wrapped formatter.
      #
      # @param entry [Lumberjack::LogEntry] The log entry to format
      # @return [String] The formatted log entry
      def call(entry)
        @formatter.call(entry.severity_label, entry.time, entry.progname, entry.message)
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

    TEMPLATE_ARGUMENT_ORDER = %w[
      time
      severity
      severity(padded)
      severity(char)
      severity(emoji)
      severity(level)
      progname
      pid
      message
      attributes
    ].freeze

    MILLISECOND_TIME_FORMAT = "%Y-%m-%dT%H:%M:%S.%3N"
    MICROSECOND_TIME_FORMAT = "%Y-%m-%dT%H:%M:%S.%6N"
    PLACEHOLDER_PATTERN = /{{ *((?:[^}]|}(?!}))*) *}}/i
    V1_PLACEHOLDER_PATTERN = /:[a-z0-9_.-]+/i
    RESET_CHAR = "\e[0m"
    private_constant :TEMPLATE_ARGUMENT_ORDER, :MILLISECOND_TIME_FORMAT, :MICROSECOND_TIME_FORMAT, :PLACEHOLDER_PATTERN, :V1_PLACEHOLDER_PATTERN, :RESET_CHAR

    # Create a new template with customizable formatting options. The template
    # supports different formatting for single-line and multi-line messages,
    # custom time formatting, and configurable attribute display.
    #
    # @param first_line [String, nil] Template for formatting the first line of messages.
    #   Defaults to <code>[{{ time }} {{ severity(padded) }} {{ progname }}({{ pid }})] {{ message }} {{ attributes }}</code>
    # @param additional_lines [String, nil] Template for formatting additional lines
    #   in multi-line messages. Defaults to <code>\\n> {{ message }}</code>
    # @param time_format [String, Symbol, nil] Time formatting specification. Can be:
    #   - A strftime format string (e.g., "%Y-%m-%d %H:%M:%S")
    #   - +:milliseconds+ for ISO format with millisecond precision (default)
    #   - +:microseconds+ for ISO format with microsecond precision
    # @param attribute_format [String, nil] Printf-style format for individual attributes.
    #   Must contain exactly two %s placeholders for name and value. Defaults to "[%s:%s]"
    # @param colorize [Boolean] Whether to colorize the log entry based on severity (default: false)
    # @raise [ArgumentError] If attribute_format doesn't contain exactly two %s placeholders
    def initialize(first_line = nil, additional_lines: nil, time_format: nil, attribute_format: nil, colorize: false)
      first_line ||= DEFAULT_FIRST_LINE_TEMPLATE
      first_line = "#{first_line.chomp}#{Lumberjack::LINE_SEPARATOR}"
      if !first_line.include?("{{") && first_line.match?(V1_PLACEHOLDER_PATTERN)
        Utils.deprecated("Template.v1", "Templates now use {{placeholder}} instead of :placeholder and :tags has been replaced with {{attributes}}.") do
          @first_line_template, @first_line_attributes = compile_v1(first_line)
        end
      else
        @first_line_template, @first_line_attributes = compile(first_line)
      end

      additional_lines ||= DEFAULT_ADDITIONAL_LINES_TEMPLATE
      if !additional_lines.include?("{{") && additional_lines.match?(V1_PLACEHOLDER_PATTERN)
        Utils.deprecated("Template.v1", "Templates now use {{placeholder}} instead of :placeholder and :tags has been replaced with {{attributes}}.") do
          @additional_line_template, @additional_line_attributes = compile_v1(additional_lines)
        end
      else
        @additional_line_template, @additional_line_attributes = compile(additional_lines)
      end

      @attribute_template = attribute_format || DEFAULT_ATTRIBUTE_FORMAT
      unless @attribute_template.scan("%s").size == 2
        raise ArgumentError.new("attribute_format must be a printf template with exactly two '%s' placeholders")
      end

      # Formatting the time is relatively expensive, so only do it if it will be used
      @template_include_time = "#{@first_line_template} #{@additional_line_template}".include?("%1$s")
      self.datetime_format = (time_format || :milliseconds)

      @colorize = colorize
    end

    # Set the datetime format used for timestamp formatting in the template.
    # This method accepts both strftime format strings and symbolic shortcuts.
    #
    # @param format [String, Symbol] The datetime format specification:
    #   - String: A strftime format pattern (e.g., "%Y-%m-%d %H:%M:%S")
    #   - +:milliseconds+: ISO format with millisecond precision (YYYY-MM-DDTHH:MM:SS.sss)
    #   - +:microseconds+: ISO format with microsecond precision (YYYY-MM-DDTHH:MM:SS.ssssss)
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
      severity = entry.severity_data
      format_args = [
        formatted_time,
        severity.label,
        severity.padded_label,
        severity.char,
        severity.emoji,
        severity.level,
        entry.progname,
        entry.pid,
        first_line
      ]
      append_attribute_args!(format_args, entry.attributes, @first_line_attributes)
      message = (@first_line_template % format_args)

      if additional_lines && !additional_lines.empty?
        format_args.slice!(9, format_args.size)
        append_attribute_args!(format_args, entry.attributes, @additional_line_attributes)

        message_length = message.length
        message.chomp!(Lumberjack::LINE_SEPARATOR)
        chomped = message.length != message_length

        additional_lines.each do |line|
          format_args[8] = line
          line_message = @additional_line_template % format_args
          message << line_message
        end

        message << Lumberjack::LINE_SEPARATOR if chomped
      end

      message = colorize_entry(message, entry) if @colorize

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
      template = template.gsub(/ ({{ *)attributes( *}})/, "\\1attributes\\2")
      template = template.gsub(/%(?!%)/, "%%")

      attribute_vars = []
      template = template.gsub(PLACEHOLDER_PATTERN) do |match|
        var_name = match.sub(/{{ */, "").sub(/ *}}/, "")
        position = TEMPLATE_ARGUMENT_ORDER.index(var_name)
        if position
          "%#{position + 1}$s"
        else
          attribute_vars << var_name
          "%#{TEMPLATE_ARGUMENT_ORDER.size + attribute_vars.size}$s"
        end
      end
      [template, attribute_vars]
    end

    # Parse and compile a template string into a sprintf-compatible format string
    # and extract attribute variable names. This method handles placeholder
    # substitution and escape sequence processing.
    #
    # @param template [String] The raw template string with placeholders
    # @return [Array<String, Array<String>>] A tuple of [compiled_template, attribute_vars]
    def compile_v1(template) # :nodoc:
      template = template.gsub(":tags", ":attributes").gsub(/ ?:attributes/, ":attributes")
      template = template.gsub(/%(?!%)/, "%%")

      attribute_vars = []
      template = template.gsub(V1_PLACEHOLDER_PATTERN) do |match|
        var_name = match[1, match.length]
        position = TEMPLATE_ARGUMENT_ORDER.index(var_name)
        if position
          "%#{position + 1}$s"
        else
          attribute_vars << var_name
          "%#{TEMPLATE_ARGUMENT_ORDER.size + attribute_vars.size}$s"
        end
      end
      [template, attribute_vars]
    end

    def colorize_entry(formatted_string, entry)
      color_start = entry.severity_data.terminal_color
      formatted_string.split(Lumberjack::LINE_SEPARATOR).collect do |line|
        "#{color_start}#{line}#{RESET_CHAR}"
      end.join(Lumberjack::LINE_SEPARATOR)
    end
  end
end
