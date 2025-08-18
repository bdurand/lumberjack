# frozen_string_literal: true

module Lumberjack
  # An entry in a log is a data structure that captures the log message as well as
  # information about the system that logged the message.
  class LogEntry
    attr_accessor :time, :message, :severity, :progname, :pid, :attributes

    TIME_FORMAT = "%Y-%m-%dT%H:%M:%S"

    # Create a new log entry.
    #
    # @param time [Time] The time the log entry was created.
    # @param severity [Integer, String] The severity of the log entry.
    # @param message [String] The message to log.
    # @param progname [String] The name of the program that created the log entry.
    # @param pid [Integer] The process id of the program that created the log entry.
    # @param attributes [Hash<String, Object>] A hash of attributes to associate with the log entry.
    def initialize(time, severity, message, progname, pid, attributes)
      @time = time
      @severity = (severity.is_a?(Integer) ? severity : Severity.label_to_level(severity))
      @message = message
      @progname = progname
      @pid = pid
      @attributes = compact_attributes(attributes) if attributes.is_a?(Hash)
    end

    def severity_label
      Severity.level_to_label(severity)
    end

    def to_s
      "[#{time.strftime(TIME_FORMAT)}.#{(time.usec / 1000.0).round.to_s.rjust(3, "0")} #{severity_label} #{progname}(#{pid})#{attributes_to_s}] #{message}"
    end

    def inspect
      to_s
    end

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

    # Return the tag with the specified name.
    #
    # @param name [String, Symbol] The tag name.
    # @return [Object, nil] The tag value or nil if the tag does not exist.
    def [](name)
      TagContext.new(attributes)[name]
    end

    def tag(name)
      self[name]
    end

    # Helper method to expand the attributes into a nested structure. attributes with dots in the name
    # will be expanded into nested hashes.
    #
    # @return [Hash] The attributes expanded into a nested structure.
    #
    # @example
    #   entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, "a.b.c" => 1, "a.b.d" => 2)
    #   entry.nested_attributes # => {"a" => {"b" => {"c" => 1, "d" => 2}}}
    def nested_attributes
      Utils.expand_attributes(attributes)
    end

    def nested_tags
      nested_attributes
    end

    # Return true if the log entry has no message and no attributes.
    #
    # @return [Boolean] True if the log entry is empty, false otherwise.
    def empty?
      (message.nil? || message == "") && (attributes.nil? || attributes.empty?)
    end

    private

    def attributes_to_s
      attributes_string = +""
      attributes&.each { |name, value| attributes_string << " #{name}:#{value.inspect}" }
      attributes_string
    end

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
