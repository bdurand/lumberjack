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
  # A matcher can optionally be constructed with an entry formatter. Filter
  # values are always compared raw first. If a raw comparison fails, the filter
  # value is run through the formatter and compared again. Since log entries
  # are formatted before they are written to a device, this allows expectations
  # to be written with unformatted values (an Exception, for example) and still
  # match the formatted values captured on the entry.
  #
  # @see Lumberjack::Device::Test
  class LogEntryMatcher
    require_relative "log_entry_matcher/indifferent_hash"
    require_relative "log_entry_matcher/score"

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
    # @param attributes [Hash, Object, nil] Hash of attribute patterns to match against
    #   log entry attributes. Supports nested attribute matching and dot notation.
    #   Any other object is matched against the entire attributes hash with ===
    #   so matchers like RSpec's hash_including can be used.
    # @param formatter [Lumberjack::EntryFormatter, Lumberjack::Logger, nil] Optional
    #   formatter used to format filter values when a raw comparison fails. A Logger
    #   can be passed to use its entry formatter. The message filter is formatted with
    #   the message formatter; when the result is a MessageAttributes, only the message
    #   part is used and the derived attributes are ignored. Attribute filter values are
    #   formatted with the attribute formatter using their dot notation names. Pattern
    #   objects (classes, regular expressions, ranges, procs, hashes, and test framework
    #   matchers) are never formatted.
    # @raise [ArgumentError] If the formatter is not an EntryFormatter or a Logger.
    def initialize(message: nil, severity: nil, progname: nil, attributes: nil, formatter: nil)
      message = message.strip if message.is_a?(String)
      @message_filter = message
      @severity_filter = Severity.coerce(severity) if severity
      @progname_filter = progname
      if attributes
        @attributes_filter = attributes.is_a?(Hash) ? Utils.expand_attributes(attributes) : attributes
      end
      @formatter = resolve_formatter(formatter)
      @formatted_attribute_filters = {}
    end

    # Test whether a log entry matches all specified criteria. The entry must
    # satisfy all non-nil filter conditions to be considered a match. Uses
    # case equality (===) for flexible pattern matching.
    #
    # @param entry [Lumberjack::LogEntry] The log entry to test against the matcher
    # @return [Boolean] True if the entry matches all specified criteria, false otherwise
    def match?(entry)
      diff(entry).empty?
    end

    # Compare a log entry against the matcher criteria and return only the fields
    # that do not match. An empty hash means the entry matches, so
    # +diff(entry).empty?+ is always equal to +match?(entry)+.
    #
    # The returned hash uses string keys for the fields ("message", "severity",
    # "progname", and "attributes"). Each mismatched field maps to a hash with
    # +:expected+ and +:actual+ (the entry value). Severity values are converted
    # to labels on both sides for readability. When a formatter is set and the
    # filter value was formatted, +:expected+ shows the formatted filter value
    # so both sides of the mismatch are in the same form.
    #
    # Attribute mismatches are reported per attribute using dot notation keys.
    # A missing attribute is reported with +actual: nil+. An attribute that was
    # expected to be absent (a nil or empty filter value) is reported with the
    # raw filter as +:expected+ and the entry value as +:actual+. When the
    # attributes filter is not a hash (a matcher object applied to the whole
    # attributes hash), a failure is reported as a single hash with +:expected+
    # and +:actual+ keys instead of per attribute detail.
    #
    # @param entry [Lumberjack::LogEntry] The log entry to compare against the matcher
    # @return [Hash] A hash of the fields that do not match; empty if the entry matches
    def diff(entry)
      result = {}

      unless match_message?(entry.message)
        result["message"] = {expected: expected_message, actual: entry.message}
      end

      unless match_filter?(entry.severity, @severity_filter)
        result["severity"] = {expected: Severity.level_to_label(@severity_filter), actual: entry.severity_label}
      end

      unless match_filter?(entry.progname, @progname_filter)
        result["progname"] = {expected: @progname_filter, actual: entry.progname}
      end

      if @attributes_filter
        attributes = IndifferentHash.wrap(Utils.expand_attributes(entry.attributes))
        if @attributes_filter.is_a?(Hash)
          mismatches = attribute_mismatches(attributes, @attributes_filter)
          result["attributes"] = mismatches unless mismatches.empty?
        elsif !match_filter?(attributes, @attributes_filter)
          result["attributes"] = {expected: @attributes_filter, actual: attributes}
        end
      end

      result
    end

    # Find the closest matching log entry from a list of candidates. This method
    # scores each entry based on how well it matches the specified criteria and
    # returns the entry with the highest score, provided it meets a minimum
    # threshold. If no entries meet the threshold, nil is returned.
    #
    # @param entries [Array<Lumberjack::LogEntry>] The list of log entries to evaluate
    # @return [Lumberjack::LogEntry, nil] The closest matching log entry or nil if none match
    def closest(entries)
      scored_entries = entries.map { |entry| [entry, entry_score(entry)] }
      best_score = scored_entries.max_by { |_, score| score }
      (best_score&.last.to_f >= Score::MIN_SCORE_THRESHOLD) ? best_score.first : nil
    end

    private

    def entry_score(entry)
      Score.calculate_match_score(
        entry,
        message: @message_filter,
        severity: @severity_filter,
        attributes: @attributes_filter,
        progname: @progname_filter
      )
    end

    # Coerce the formatter argument into an EntryFormatter or nil.
    #
    # @param formatter [Lumberjack::EntryFormatter, Lumberjack::Logger, nil] The formatter argument.
    # @return [Lumberjack::EntryFormatter, nil] The resolved entry formatter.
    def resolve_formatter(formatter)
      return nil if formatter.nil?
      return formatter if formatter.is_a?(Lumberjack::EntryFormatter)

      if formatter.respond_to?(:formatter) && formatter.formatter.is_a?(Lumberjack::EntryFormatter)
        formatter.formatter
      else
        raise ArgumentError.new("formatter must be a Lumberjack::EntryFormatter or Lumberjack::Logger")
      end
    end

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

    # Match the message filter against an entry message. If the raw comparison
    # fails, the filter is formatted with the message formatter and compared again.
    #
    # @param message [Object] The entry message.
    # @return [Boolean] True if the message matches.
    def match_message?(message)
      return true if match_filter?(message, @message_filter)
      return false if @formatter.nil? || @message_filter.nil? || pattern_filter?(@message_filter)

      formatted = formatted_message_filter
      return false if formatted.equal?(@message_filter)

      match_filter?(message, formatted)
    end

    # The message filter value to report in a diff. The formatted value is used
    # when the formatter changed the filter so both sides of a mismatch are in
    # the same form.
    #
    # @return [Object] The message filter value to report.
    def expected_message
      if @formatter && !@message_filter.nil? && !pattern_filter?(@message_filter)
        formatted_message_filter
      else
        @message_filter
      end
    end

    # Format the message filter with the message formatter. The result is
    # memoized so the formatter is only invoked once per matcher.
    #
    # @return [Object] The formatted message filter.
    def formatted_message_filter
      return @formatted_message_filter if defined?(@formatted_message_filter)

      value = @message_filter
      message_formatter = @formatter.message_formatter
      if message_formatter.respond_to?(:format)
        begin
          value = message_formatter.format(@message_filter)
        rescue
          value = @message_filter
        end
      end
      value = value.message if value.is_a?(MessageAttributes)
      value = value.strip if value.is_a?(String)
      @formatted_message_filter = value
    end

    # Recursively compare attribute filter patterns against entry attributes and
    # collect the mismatches. Keys in the returned hash use dot notation.
    #
    # @param attributes [Hash] The expanded attributes hash from the log entry.
    # @param filter [Hash] The filter patterns to match against the attributes.
    # @param path [String, nil] The dot notation path of the current nesting level.
    # @param allow_formatting [Boolean] Whether filter values can be formatted on a failed comparison.
    # @return [Hash] The mismatched attributes keyed by dot notation name.
    def attribute_mismatches(attributes, filter, path = nil, allow_formatting: true)
      mismatches = {}

      filter.each do |name, value_filter|
        name = name.to_s
        key = path ? "#{path}.#{name}" : name
        attribute_value = attributes[name]

        if attribute_value.is_a?(Hash)
          if value_filter.is_a?(Hash)
            mismatches.merge!(attribute_mismatches(attribute_value, value_filter, key, allow_formatting: allow_formatting))
          else
            add_leaf_mismatches(mismatches, key, attribute_value, value_filter, allow_formatting)
          end
        elsif value_filter.nil? || (value_filter.is_a?(Enumerable) && value_filter.empty?)
          empty_value = attribute_value.nil? || (attribute_value.is_a?(Array) && attribute_value.empty?)
          mismatches[key] = {expected: value_filter, actual: attribute_value} unless empty_value
        elsif attributes.include?(name)
          add_leaf_mismatches(mismatches, key, attribute_value, value_filter, allow_formatting)
        else
          mismatches[key] = {expected: value_filter, actual: nil}
        end
      end

      mismatches
    end

    # Match a single attribute value against a filter and add any mismatches to
    # the collector. If the raw comparison fails, the filter is formatted with the
    # attribute formatter and compared again. Mismatches are reported with the
    # formatted filter value so both sides are in the same form. A formatted result
    # that is a hash is compared recursively against the entry value with formatting
    # disabled since its values are already formatted, and mismatches are reported
    # per attribute under the leaf's dot notation name.
    #
    # @param mismatches [Hash] The mismatch collector.
    # @param path [String] The dot notation name of the attribute.
    # @param value [Object] The entry attribute value.
    # @param filter [Object] The filter pattern.
    # @param allow_formatting [Boolean] Whether the filter can be formatted on a failed comparison.
    # @return [void]
    def add_leaf_mismatches(mismatches, path, value, filter, allow_formatting)
      return if match_filter?(value, filter)

      unless allow_formatting && @formatter && !pattern_filter?(filter)
        mismatches[path] = {expected: filter, actual: value}
        return
      end

      formatted = formatted_attribute_filter(path, filter)
      if formatted.equal?(filter)
        mismatches[path] = {expected: filter, actual: value}
      elsif formatted.is_a?(Hash)
        if value.is_a?(Hash)
          mismatches.merge!(attribute_mismatches(value, Utils.expand_attributes(formatted), path, allow_formatting: false))
        else
          mismatches[path] = {expected: formatted, actual: value}
        end
      elsif !match_filter?(value, formatted)
        mismatches[path] = {expected: formatted, actual: value}
      end
    end

    # Determine if a filter is a pattern that must never be formatted since
    # formatting it would destroy its matching behavior.
    #
    # @param filter [Object] The filter to check.
    # @return [Boolean] True if the filter is a pattern object.
    def pattern_filter?(filter)
      filter.is_a?(Module) || filter.is_a?(Regexp) || filter.is_a?(Range) ||
        filter.is_a?(Proc) || filter.is_a?(Hash) || filter.respond_to?(:matches?)
    end

    # Format an attribute filter value with the attribute formatter using its dot
    # notation name so name based formatters apply. Results are memoized per name.
    # The raw filter is returned if formatting fails or removes the attribute.
    #
    # @param path [String] The dot notation name of the attribute.
    # @param filter [Object] The filter value to format.
    # @return [Object] The formatted filter value.
    def formatted_attribute_filter(path, filter)
      return @formatted_attribute_filters[path] if @formatted_attribute_filters.include?(path)

      attribute_formatter = @formatter.attribute_formatter
      formatted = filter
      if attribute_formatter.respond_to?(:format)
        begin
          result = attribute_formatter.format({path => filter})
          formatted = result.fetch(path, filter) if result.is_a?(Hash)
        rescue
          formatted = filter
        end
      end
      @formatted_attribute_filters[path] = formatted
    end
  end
end
