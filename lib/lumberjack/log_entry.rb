# frozen_string_literal: true

module Lumberjack
  # An entry in a log is a data structure that captures the log message as well as
  # information about the system that logged the message.
  class LogEntry
    attr_accessor :time, :message, :severity, :progname, :pid, :tags

    TIME_FORMAT = "%Y-%m-%dT%H:%M:%S"

    # Create a new log entry.
    #
    # @param time [Time] The time the log entry was created.
    # @param severity [Integer, String] The severity of the log entry.
    # @param message [String] The message to log.
    # @param progname [String] The name of the program that created the log entry.
    # @param pid [Integer] The process id of the program that created the log entry.
    # @param tags [Hash<String, Object>] A hash of tags to associate with the log entry.
    def initialize(time, severity, message, progname, pid, tags)
      @time = time
      @severity = (severity.is_a?(Integer) ? severity : Severity.label_to_level(severity))
      @message = message
      @progname = progname
      @pid = pid
      @tags = compact_tags(tags) if tags.is_a?(Hash)
    end

    def severity_label
      Severity.level_to_label(severity)
    end

    def to_s
      "[#{time.strftime(TIME_FORMAT)}.#{(time.usec / 1000.0).round.to_s.rjust(3, "0")} #{severity_label} #{progname}(#{pid})#{tags_to_s}] #{message}"
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
        tags == other.tags
    end

    # Return the tag with the specified name.
    #
    # @param name [String, Symbol] The tag name.
    # @return [Object, nil] The tag value or nil if the tag does not exist.
    def tag(name)
      TagContext.new(tags)[name]
    end

    # Helper method to expand the tags into a nested structure. Tags with dots in the name
    # will be expanded into nested hashes.
    #
    # @return [Hash] The tags expanded into a nested structure.
    #
    # @example
    #   entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, "a.b.c" => 1, "a.b.d" => 2)
    #   entry.nested_tags # => {"a" => {"b" => {"c" => 1, "d" => 2}}}
    def nested_tags
      Utils.expand_tags(tags)
    end

    # Return true if the log entry has no message and no tags.
    #
    # @return [Boolean] True if the log entry is empty, false otherwise.
    def empty?
      (message.nil? || message == "") && (tags.nil? || tags.empty?)
    end

    private

    def tags_to_s
      tags_string = +""
      tags&.each { |name, value| tags_string << " #{name}:#{value.inspect}" }
      tags_string
    end

    def compact_tags(tags)
      delete_keys = nil
      compacted_keys = nil

      tags.each do |key, value|
        if value.nil? || value == ""
          delete_keys ||= []
          delete_keys << key
        elsif value.is_a?(Hash)
          compacted_value = compact_tags(value)
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

      return tags if delete_keys.nil? && compacted_keys.nil?

      tags = tags.dup
      delete_keys&.each { |key| tags.delete(key) }
      compacted_keys&.each { |key, value| tags[key] = value }

      tags
    end
  end
end
