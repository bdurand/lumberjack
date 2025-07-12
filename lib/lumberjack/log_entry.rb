# frozen_string_literal: true

module Lumberjack
  # An entry in a log is a data structure that captures the log message as well as
  # information about the system that logged the message.
  class LogEntry
    attr_accessor :time, :message, :severity, :progname, :pid, :tags

    TIME_FORMAT = "%Y-%m-%dT%H:%M:%S"

    # @deprecated Will be removed in version 2.0.
    UNIT_OF_WORK_ID = "unit_of_work_id"

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
      # backward compatibility with 1.0 API where the last argument was the unit of work id
      @tags = if tags.nil? || tags.is_a?(Hash)
        tags
      else
        {UNIT_OF_WORK_ID => tags}
      end
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

    # @deprecated - backward compatibility with 1.0 API. Will be removed in version 2.0.
    def unit_of_work_id
      tags[UNIT_OF_WORK_ID] if tags
    end

    # @deprecated - backward compatibility with 1.0 API. Will be removed in version 2.0.
    def unit_of_work_id=(value)
      if tags
        tags[UNIT_OF_WORK_ID] = value
      else
        @tags = {UNIT_OF_WORK_ID => value}
      end
    end

    # Return the tag with the specified name.
    def tag(name)
      tags[name.to_s] if tags
    end

    # Return true if the log entry has no message and no tags.
    def empty?
      (message.nil? || message == "") && (tags.nil? || tags.empty?)
    end

    private

    def tags_to_s
      tags_string = +""
      tags&.each { |name, value| tags_string << " #{name}:#{value.inspect}" }
      tags_string
    end
  end
end
