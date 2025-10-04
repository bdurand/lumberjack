# frozen_string_literal: true

module Lumberjack
  # The standard severity levels for logging messages.
  module Severity
    # Custom severity level for trace messages, lower than DEBUG.
    TRACE = -1

    DEBUG = Logger::Severity::DEBUG
    INFO = Logger::Severity::INFO
    WARN = Logger::Severity::WARN
    ERROR = Logger::Severity::ERROR
    FATAL = Logger::Severity::FATAL
    UNKNOWN = Logger::Severity::UNKNOWN

    SEVERITY_LABELS = %w[TRACE DEBUG INFO WARN ERROR FATAL ANY].freeze
    private_constant :SEVERITY_LABELS

    # Data object for severity levels that includes variations on the label.
    class Data
      attr_reader :level, :label, :padded_label, :char, :emoji, :terminal_color

      def initialize(level, label, emoji, terminal_color)
        @level = level
        @label = label.freeze
        @padded_label = label.ljust(5).freeze
        @char = label[0].freeze
        @emoji = emoji.freeze
        @terminal_color = "\e[38;5;#{terminal_color}m"
      end
    end

    SEVERITIES = [
      Data.new(TRACE, "TRACE", "🔍", 247).freeze,
      Data.new(DEBUG, "DEBUG", "⚙️", 244).freeze,
      Data.new(INFO, "INFO", "🔵", 33).freeze,
      Data.new(WARN, "WARN", "🟡", 208).freeze,
      Data.new(ERROR, "ERROR", "❌", 9).freeze,
      Data.new(FATAL, "FATAL", "🔥", 160).freeze,
      Data.new(UNKNOWN, "ANY", "❓", 129).freeze
    ].freeze
    private_constant :SEVERITIES

    class << self
      # Convert a severity level to a label.
      #
      # @param severity [Integer] The severity level to convert.
      # @return [String] The severity label.
      def level_to_label(severity)
        SEVERITIES[severity + 1]&.label || SEVERITIES.last.label
      end

      # Convert a severity label to a level.
      #
      # @param label [String, Symbol] The severity label to convert.
      # @return [Integer] The severity level.
      def label_to_level(label)
        label = label.to_s.upcase
        (SEVERITY_LABELS.index(label) || UNKNOWN + 1) - 1
      end

      # Coerce a value to a severity level.
      #
      # @param value [Integer, String, Symbol] The value to coerce.
      # @return [Integer] The severity level.
      def coerce(value)
        if value.is_a?(Numeric)
          value.to_i
        else
          label_to_level(value)
        end
      end

      # Return a data object that maps the severity level to variations on the label.
      #
      # @param level [Integer, String, Symbol] The severity level.
      # @return [SeverityData] The severity data object.
      def data(level)
        SEVERITIES[coerce(level) + 1] || SEVERITIES.last
      end
    end
  end
end
