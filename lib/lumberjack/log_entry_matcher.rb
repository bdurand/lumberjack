# frozen_string_literal: true

module Lumberjack
  # A flexible matching utility for testing and filtering log entries based on
  # multiple criteria. This class provides pattern-based matching against log
  # entry components including message content, severity levels, program names,
  # and custom attributes with support for nested attribute structures.
  #
  # The matcher uses Ruby's case equality operator (===) for flexible matching,
  # supporting exact values, regular expressions, ranges, classes, and other
  # pattern matching constructs. It's primarily designed for use with the Test
  # device in testing scenarios but can be used anywhere log entry filtering
  # is needed.
  #
  # @see Lumberjack::Device::Test
  class LogEntryMatcher
    # Create a new log entry matcher with optional filtering criteria. All
    # parameters are optional and nil values indicate no filtering for that
    # component. The matcher uses case equality (===) for flexible pattern
    # matching against each specified criterion.
    #
    # @param message [Object, nil] Pattern to match against log entry messages.
    #   Supports strings, regular expressions, or any object responding to ===
    # @param severity [Integer, String, Symbol, nil] Severity level to match.
    #   Accepts numeric levels or symbolic names (:debug, :info, etc.)
    # @param progname [Object, nil] Pattern to match against program names.
    #   Supports strings, regular expressions, or any object responding to ===
    # @param attributes [Hash, nil] Hash of attribute patterns to match against
    #   log entry attributes. Supports nested attribute matching and dot notation
    def initialize(message: nil, severity: nil, progname: nil, attributes: nil)
      @message_filter = message
      @severity_filter = Severity.coerce(severity) if severity
      @progname_filter = progname
      @attributes_filter = Utils.expand_attributes(attributes) if attributes
    end

    # Test whether a log entry matches all specified criteria. The entry must
    # satisfy all non-nil filter conditions to be considered a match. Uses
    # case equality (===) for flexible pattern matching.
    #
    # @param entry [Lumberjack::LogEntry] The log entry to test against the matcher
    # @return [Boolean] True if the entry matches all specified criteria, false otherwise
    def match?(entry)
      return false unless match_filter?(entry.message, @message_filter)
      return false unless match_filter?(entry.severity, @severity_filter)
      return false unless match_filter?(entry.progname, @progname_filter)

      if @attributes_filter
        attributes = Utils.expand_attributes(entry.attributes)
        return false unless match_attributes?(attributes, @attributes_filter)
      end

      true
    end

    private

    # Apply a filter pattern against a value using case equality. Returns true
    # if no filter is specified (nil) or if the filter matches the value.
    #
    # @param value [Object] The value to test against the filter
    # @param filter [Object, nil] The filter pattern, nil means no filtering
    # @return [Boolean] True if the filter matches or is nil, false otherwise
    def match_filter?(value, filter)
      return true if filter.nil?

      filter === value
    end

    # Recursively match nested attribute structures against filter patterns.
    # Handles both simple attribute matching and complex nested hash structures
    # with support for partial matching and empty value detection.
    #
    # @param attributes [Hash] The expanded attributes hash from the log entry
    # @param filter [Hash] The filter patterns to match against attributes
    # @return [Boolean] True if all filter patterns match their corresponding attributes
    def match_attributes?(attributes, filter)
      return true unless filter
      return false unless attributes

      filter.all? do |name, value_filter|
        name = name.to_s
        attribute_values = attributes[name]
        if attribute_values.is_a?(Hash)
          if value_filter.is_a?(Hash)
            match_attributes?(attribute_values, value_filter)
          else
            match_filter?(attribute_values, value_filter)
          end
        elsif value_filter.nil? || (value_filter.is_a?(Enumerable) && value_filter.empty?)
          attribute_values.nil? || (attribute_values.is_a?(Array) && attribute_values.empty?)
        elsif attributes.include?(name)
          match_filter?(attribute_values, value_filter)
        else
          false
        end
      end
    end
  end
end
