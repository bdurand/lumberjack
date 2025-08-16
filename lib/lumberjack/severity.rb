# frozen_string_literal: true

module Lumberjack
  # The standard severity levels for logging messages.
  module Severity
    TRACE = -1

    TRACE_LABEL = "TRACE"
    private_constant :TRACE_LABEL

    SEVERITY_LABELS = %w[DEBUG INFO WARN ERROR FATAL ANY].freeze
    private_constant :SEVERITY_LABELS

    class << self
      # Convert a severity level to a label.
      #
      # @param [Integer] severity The severity level to convert.
      # @return [String] The severity label.
      def level_to_label(severity)
        return TRACE_LABEL if severity == TRACE
        SEVERITY_LABELS[severity] || SEVERITY_LABELS.last
      end

      # Convert a severity label to a level.
      #
      # @param [String, Symbol] label The severity label to convert.
      # @return [Integer] The severity level.
      def label_to_level(label)
        label = label.to_s.upcase
        SEVERITY_LABELS.index(label) || ((label == TRACE_LABEL) ? TRACE : Logger::UNKNOWN)
      end

      # Coerce a value to a severity level.
      #
      # @param [Integer, String, Symbol] value The value to coerce.
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
