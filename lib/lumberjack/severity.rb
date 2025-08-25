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

    PADDED_SEVERITY_LABELS = SEVERITY_LABELS.map { |label| label.ljust(5) }.freeze
    private_constant :PADDED_SEVERITY_LABELS

    class << self
      # Convert a severity level to a label.
      #
      # @param severity [Integer] The severity level to convert.
      # @return [String] The severity label.
      def level_to_label(severity, padded = false)
        if padded
          PADDED_SEVERITY_LABELS[severity + 1] || PADDED_SEVERITY_LABELS.last
        else
          SEVERITY_LABELS[severity + 1] || SEVERITY_LABELS.last
        end
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
    end
  end
end
