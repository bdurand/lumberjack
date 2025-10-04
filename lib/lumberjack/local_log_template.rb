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
    # @option options [Boolean] :emoji If true, add emojis with severity levels. Defaults to false.
    def initialize(options = {})
      self.exclude_progname = options.fetch(:exclude_progname, false)
      self.exclude_pid = options.fetch(:exclude_pid, true)
      self.exclude_time = options.fetch(:exclude_time, true)
      self.exclude_attributes = options.fetch(:exclude_attributes, nil)
      self.colorize = options.fetch(:colorize, false)
      self.emoji = options.fetch(:emoji, false)
    end

    # Format a log entry according to the template.
    #
    # @param entry [LogEntry] The log entry to format.
    # @return [String] The formatted log entry.
    def call(entry)
      formatted = +""
      formatted << "#{entry.severity_data.emoji} " if emoji?
      formatted << entry.time.strftime("%Y-%m-%d %H:%M:%S.%6N ") unless exclude_time?
      formatted << "#{entry.severity_label} #{entry.message}"
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

    # Return true if emojis are enabled, false otherwise.
    #
    # @return [Boolean]
    def emoji?
      @emoji
    end

    # Set whether to enable emojis.
    #
    # @param value [Boolean]
    # @return [void]
    def emoji=(value)
      @emoji = !!value
    end
  end
end
