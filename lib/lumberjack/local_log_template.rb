# frozen_string_literal: true

module Lumberjack
  # This is a log template designed for local environments. It provides a simple,
  # human-readable format that includes key information about log entries while
  # omitting extraneous details. The template can be configured to include or
  # exclude certain components such as the times, process ID, program name,
  # and attributes.
  #
  # It is registered with the TemplateRegistry as :local.
  #
  # @see Template
  class LocalLogTemplate
    TemplateRegistry.add(:local, self)

    # Create a new LocalLogTemplate instance.
    #
    # @param options [Hash] Options for configuring the template.
    # @option options [Boolean, Array<String>, nil] :exclude_attributes If true, all attributes are excluded.
    #   If an array of strings is provided, those attributes (and their sub-attributes) are excluded.
    #   Defaults to nil (include all attributes).
    # @option options [Boolean] :exclude_progname If true, the progname is excluded. Defaults to false.
    # @option options [Boolean] :exclude_pid If true, the process ID is excluded. Defaults to true.
    # @option options [Boolean] :exclude_time If true, the time is excluded. Defaults to true.
    # @option options [Boolean] :colorize If true, colorize the output based on severity. Defaults to false.
    # @option options [Symbol, Formatter, #call] :exception_formatter The formatter to use for exceptions in messages.
    #   Can be a symbol registered in the FormatterRegistry, a Formatter instance, or any object that responds to #call.
    #   Defaults to nil (use default exception formatting). If the logger does not have an exception formatter
    #   configured, then the device will use this to format exceptions.
    # @option options [String, Symbol] :severity_format The optional format for severity labels (padded, char, emoji).
    def initialize(options = {})
      self.exclude_progname = options.fetch(:exclude_progname, false)
      self.exclude_pid = options.fetch(:exclude_pid, true)
      self.exclude_time = options.fetch(:exclude_time, true)
      self.exclude_attributes = options.fetch(:exclude_attributes, nil)
      self.colorize = options.fetch(:colorize, false)
      self.severity_format = options.fetch(:severity_format, nil)
      self.exception_formatter = options.fetch(:exception_formatter, :exception)
    end

    # Format a log entry according to the template.
    #
    # @param entry [LogEntry] The log entry to format.
    # @return [String] The formatted log entry.
    def call(entry)
      message = entry.message
      if message.is_a?(Exception) && exception_formatter
        message = exception_formatter.call(message)
      end

      formatted = +""
      formatted << entry.time.strftime("%Y-%m-%d %H:%M:%S.%6N ") unless exclude_time?
      formatted << "#{severity_label(entry)} #{message}"
      formatted << "#{Lumberjack::LINE_SEPARATOR}    progname: #{entry.progname}" if entry.progname.to_s != "" && !exclude_progname?
      formatted << "#{Lumberjack::LINE_SEPARATOR}    pid: #{entry.pid}" unless exclude_pid?

      if entry.attributes && !entry.attributes.empty? && !exclude_attributes?
        Lumberjack::Utils.flatten_attributes(entry.attributes).to_a.sort_by(&:first).each do |name, value|
          next if @attribute_filter.any? do |filter_name|
            if name.start_with?(filter_name)
              next_char = name[filter_name.length]
              next_char.nil? || next_char == "."
            end
          end

          formatted << "#{Lumberjack::LINE_SEPARATOR}    #{name}: #{value}"
        end
      end

      formatted = Template.colorize_entry(formatted, entry) if colorize?
      formatted << Lumberjack::LINE_SEPARATOR
    end

    # Return true if all attributes are excluded, false otherwise.
    #
    # @return [Boolean]
    def exclude_attributes?
      @exclude_attributes
    end

    # Return the list of excluded attribute names.
    #
    # @return [Array<String>]
    def excluded_attributes
      @attribute_filter.dup
    end

    # Set the attributes to exclude. If set to true, all attributes are excluded.
    # If set to an array of strings, those attributes (and their sub-attributes)
    # are excluded. If set to false or nil, no attributes are excluded.
    #
    # @param value [Boolean, Array<String>, nil]
    # @return [void]
    def exclude_attributes=(value)
      @exclude_attributes = false
      @attribute_filter = []
      if value == true
        @exclude_attributes = true
      elsif value
        @attribute_filter = Array(value).map(&:to_s)
      end
    end

    # Return true if the progname is excluded, false otherwise.
    #
    # @return [Boolean]
    def exclude_progname?
      @exclude_progname
    end

    # Set whether to exclude the progname.
    #
    # @param value [Boolean]
    # @return [void]
    def exclude_progname=(value)
      @exclude_progname = !!value
    end

    # Return true if the pid is excluded, false otherwise.
    #
    # @return [Boolean]
    def exclude_pid?
      @exclude_pid
    end

    # Set whether to exclude the pid.
    #
    # @param value [Boolean]
    # @return [void]
    def exclude_pid=(value)
      @exclude_pid = !!value
    end

    # Return true if the time is excluded, false otherwise.
    #
    # @return [Boolean]
    def exclude_time?
      @exclude_time
    end

    # Set whether to exclude the time.
    #
    # @param value [Boolean]
    # @return [void]
    def exclude_time=(value)
      @exclude_time = !!value
    end

    # Return true if colorization is enabled, false otherwise.
    #
    # @return [Boolean]
    def colorize?
      @colorize
    end

    # Set whether to enable colorization.
    #
    # @param value [Boolean]
    # @return [void]
    def colorize=(value)
      @colorize = !!value
    end

    # Set the severity format.
    #
    # @param value [String, Symbol] The severity format (:padded, :char, :emoji, :level, nil).
    # @return [void]
    def severity_format=(value)
      @severity_format = value.to_s
    end

    # Return the current severity format.
    #
    # @return [String]
    attr_reader :severity_format

    # Set the exception formatter. Can be a symbol registered in the FormatterRegistry,
    # a Formatter instance, or any object that responds to #call.
    #
    # @param value [Symbol, Formatter, #call] The exception formatter to use.
    # @return [void]
    def exception_formatter=(value)
      @exception_formatter = value.is_a?(Symbol) ? FormatterRegistry.formatter(value) : value
    end

    # Return the exception formatter.
    #
    # @return [#call, nil]
    attr_reader :exception_formatter

    private

    def severity_label(entry)
      severity = entry.severity_data
      case severity_format
      when "padded"
        severity.padded_label
      when "char"
        severity.char
      when "emoji"
        severity.emoji
      when "level"
        severity.level.to_s
      else
        severity.label
      end
    end
  end
end
