# frozen_string_literal: true

module Lumberjack
  # This is a log template designed for test environments. It provides a simple,
  # human-readable format that includes key information about log entries while
  # omitting extraneous details. The template can be configured to include or
  # exclude certain components such as the times, process ID, program name,
  # and attributes.
  #
  # @see Template
  class TestLogTemplate
    # Create a new TestLogTemplate instance.
    #
    # @param exclude_attributes [Boolean, Array<String>, nil] If true, all attributes are excluded.
    #   If an array of strings is provided, those attributes (and their sub-attributes) are excluded.
    #   Defaults to nil (include all attributes).
    # @param exclude_progname [Boolean] If true, the progname is excluded. Defaults to false.
    # @param exclude_pid [Boolean] If true, the process ID is excluded. Defaults to true.
    # @param exclude_time [Boolean] If true, the time is excluded. Defaults to true.
    def initialize(exclude_attributes: nil, exclude_progname: false, exclude_pid: true, exclude_time: true)
      self.exclude_progname = exclude_progname
      self.exclude_pid = exclude_pid
      self.exclude_time = exclude_time
      self.exclude_attributes = exclude_attributes
    end

    # Format a log entry according to the template.
    #
    # @param entry [LogEntry] The log entry to format.
    # @return [String] The formatted log entry.
    def call(entry)
      formatted = +""
      formatted << entry.time.strftime("%Y-%m-%d %H:%M:%S.%6N ") unless exclude_time?
      formatted << "#{entry.severity_data.padded_label} #{entry.message}"
      formatted << "\n    progname: #{entry.progname}" if entry.progname.to_s != "" && !exclude_progname?
      formatted << "\n    pid: #{entry.pid}" unless exclude_pid?

      if entry.attributes && !entry.attributes.empty? && !exclude_attributes?
        Lumberjack::Utils.flatten_attributes(entry.attributes).to_a.sort_by(&:first).each do |name, value|
          next if @attribute_filter.any? do |filter_name|
            if name.start_with?(filter_name)
              next_char = name[filter_name.length]
              next_char.nil? || next_char == "."
            end
          end

          formatted << "\n    #{name}: #{value}"
        end
      end

      formatted
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
  end
end
