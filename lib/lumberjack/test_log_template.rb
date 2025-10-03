# frozen_string_literal: true

module Lumberjack
  # This is a log template designed for test environments. It provides a simple,
  # human-readable format that includes key information about log entries while
  # omitting extraneous details. The template can be configured to include or
  # exclude certain components such as the timestamps, process ID, program name,
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
    # @param exclude_timestamp [Boolean] If true, the timestamp is excluded. Defaults to true.
    def initialize(exclude_attributes: nil, exclude_progname: false, exclude_pid: true, exclude_timestamp: true)
      @exclude_progname = exclude_progname
      @exclude_pid = exclude_pid
      @exclude_timestamp = exclude_timestamp

      @exclude_attributes = false
      @attribute_filter = []
      if exclude_attributes == true
        @exclude_attributes = true
      elsif exclude_attributes
        @attribute_filter = Array(exclude_attributes).map(&:to_s)
      end
    end

    # Format a log entry according to the template.
    #
    # @param entry [LogEntry] The log entry to format.
    # @return [String] The formatted log entry.
    def call(entry)
      formatted = +""
      formatted << entry.time.strftime("%Y-%m-%d %H:%M:%S.%3N ") unless @exclude_timestamp
      formatted << "#{entry.severity_data.padded_label} #{entry.message}"
      formatted << "\n  progname: #{entry.progname}" if entry.progname.to_s != "" && !@exclude_progname
      formatted << "\n  pid: #{entry.pid}" unless @exclude_pid

      if entry.attributes && !entry.attributes.empty? && !@exclude_attributes
        Lumberjack::Utils.flatten_attributes(entry.attributes).to_a.sort_by(&:first).each do |name, value|
          next if @attribute_filter.any? do |filter_name|
            if name.start_with?(filter_name)
              next_char = name[filter_name.length]
              next_char.nil? || next_char == "."
            end
          end

          formatted << "\n  #{name}: #{value}"
        end
      end

      formatted
    end
  end
end
