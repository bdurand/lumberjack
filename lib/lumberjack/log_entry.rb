# frozen_string_literal: true

module Lumberjack
  # A structured representation of a single log entry containing the message,
  # metadata, and contextual information. LogEntry objects are immutable data
  # structures that capture all relevant information about a logging event,
  # including timing, severity, source identification, and custom attributes.
  #
  # This class serves as the fundamental data structure passed between loggers,
  # formatters, and output devices throughout the Lumberjack logging pipeline.
  # Each entry maintains consistent structure while supporting flexible attribute
  # attachment for contextual logging scenarios.
  class LogEntry
    # @!attribute [rw] time
    #   @return [Time] The timestamp when the log entry was created
    # @!attribute [rw] message
    #   @return [String] The primary log message content
    # @!attribute [rw] severity
    #   @return [Integer] The numeric severity level of the log entry
    # @!attribute [rw] progname
    #   @return [String] The name of the program or component that generated the entry
    # @!attribute [rw] pid
    #   @return [Integer] The process ID of the logging process
    # @!attribute [rw] attributes
    #   @return [Hash<String, Object>] Custom attributes associated with the log entry
    attr_accessor :time, :message, :severity, :progname, :pid, :attributes

    TIME_FORMAT = "%Y-%m-%dT%H:%M:%S"

    # Create a new log entry with the specified components. The entry captures
    # all relevant information about a logging event in a structured format.
    #
    # @param time [Time] The timestamp when the log entry was created
    # @param severity [Integer, String, Symbol] The severity level, accepts numeric levels or labels
    # @param message [String] The primary log message content
    # @param progname [String, nil] The name of the program or component generating the entry
    # @param pid [Integer] The process ID of the logging process
    # @param attributes [Hash<String, Object>, nil] Custom attributes to associate with the entry
    def initialize(time, severity, message, progname, pid, attributes)
      @time = time
      @severity = (severity.is_a?(Integer) ? severity : Severity.label_to_level(severity))
      @message = message
      @progname = progname
      @pid = pid
      @attributes = compact_attributes(attributes) if attributes.is_a?(Hash)
    end

    # Get the human-readable severity label corresponding to the numeric severity level.
    #
    # @return [String] The severity label (DEBUG, INFO, WARN, ERROR, FATAL, or UNKNOWN)
    def severity_label(pad = false)
      Severity.level_to_label(severity, pad)
    end

    # Generate a formatted string representation of the log entry suitable for
    # human consumption. Includes timestamp, severity, program name, process ID,
    # attributes, and the main message.
    #
    # @return [String] A formatted string representation of the complete log entry
    def to_s
      "[#{time.strftime(TIME_FORMAT)}.#{(time.usec / 1000.0).round.to_s.rjust(3, "0")} #{severity_label} #{progname}(#{pid})#{attributes_to_s}] #{message}"
    end

    # Return a string representation suitable for debugging and inspection.
    #
    # @return [String] The same as {#to_s}
    def inspect
      to_s
    end

    # Compare this log entry with another for equality. Two log entries are
    # considered equal if all their components match exactly.
    #
    # @param other [Object] The object to compare against
    # @return [Boolean] True if the entries are identical, false otherwise
    def ==(other)
      return true if equal?(other)
      return false unless other.is_a?(LogEntry)

      time == other.time &&
        severity == other.severity &&
        message == other.message &&
        progname == other.progname &&
        pid == other.pid &&
        attributes == other.attributes
    end

    # Alias for tags to provide backward compatibility with version 1.x API. This method
    # will eventually be removed.
    #
    # @return [Hash, nil] The attributes of the log entry.
    # @deprecated Use {#attributes} instead.
    def tags
      Utils.deprecated(:tags, "Use attributes instead.") do
        attributes
      end
    end

    # Access an attribute value by name. Supports both simple and nested attribute
    # access using dot notation for hierarchical data structures.
    #
    # @param name [String, Symbol] The attribute name, supports dot notation for nested access
    # @return [Object, nil] The attribute value or nil if the attribute does not exist
    def [](name)
      AttributesHelper.new(attributes)[name]
    end

    # Alias method for #[] to provide backward compatibility with version 1.x API. This
    # method will eventually be removed.
    #
    # @return [Hash]
    # @deprecated Use {#[]} instead.
    def tag(name)
      Utils.deprecated(:tag, "Use [] instead.") do
        self[name]
      end
    end

    # Expand flat attributes with dot notation into a nested hash structure.
    # Attributes containing dots in their names are converted into hierarchical
    # nested hashes for structured data representation.
    #
    # @return [Hash] The attributes expanded into a nested structure
    def nested_attributes
      Utils.expand_attributes(attributes)
    end

    # Alias for nested_attributes to provide API compatibility with version 1.x.
    # This method will eventually be removed.
    #
    # @return [Hash]
    # @deprecated Use {#nested_attributes} instead.
    def nested_tags
      Utils.deprecated(:nested_tags, "Use nested_attributes instead.") do
        nested_attributes
      end
    end

    # Determine if the log entry contains no meaningful content. An entry is
    # considered empty if it has no message content and no attributes.
    #
    # @return [Boolean] True if the entry is empty, false otherwise
    def empty?
      (message.nil? || message == "") && (attributes.nil? || attributes.empty?)
    end

    # Convert the log entry into a hash suitable for JSON serialization. Attributes will be expanded
    # into a nested structure (i.e. {"user.id" => 123} becomes {"user" => {"id" => 123}}). Severities will
    # be converted to their string labels.
    #
    # @return [Hash] The JSON representation of the log entry
    def as_json
      {
        "time" => time,
        "severity" => severity_label,
        "message" => message,
        "progname" => progname,
        "pid" => pid,
        "attributes" => Utils.expand_attributes(attributes)
      }
    end

    private

    # Generate a string representation of all attributes for inclusion in the
    # formatted output. Each attribute is formatted as key:value pairs.
    #
    # @return [String] A formatted string of all attributes
    def attributes_to_s
      attributes_string = +""
      attributes&.each { |name, value| attributes_string << " #{name}:#{value.inspect}" }
      attributes_string
    end

    # Remove nil, empty string, and empty collection values from the attributes
    # hash recursively. This cleanup ensures that meaningless attributes don't
    # clutter the log entry while preserving all meaningful data.
    #
    # @param attributes [Hash] The attributes hash to compact
    # @return [Hash] A new hash with empty values removed
    def compact_attributes(attributes)
      delete_keys = nil
      compacted_keys = nil

      attributes.each do |key, value|
        if value.nil? || value == ""
          delete_keys ||= []
          delete_keys << key
        elsif value.is_a?(Hash)
          compacted_value = compact_attributes(value)
          if compacted_value.empty?
            delete_keys ||= []
            delete_keys << key
          elsif !value.equal?(compacted_value)
            compacted_keys ||= []
            compacted_keys << [key, compacted_value]
          end
        elsif value.is_a?(Array) && value.empty?
          delete_keys ||= []
          delete_keys << key
        end
      end

      return attributes if delete_keys.nil? && compacted_keys.nil?

      attributes = attributes.dup
      delete_keys&.each { |key| attributes.delete(key) }
      compacted_keys&.each { |key, value| attributes[key] = value }

      attributes
    end
  end
end
