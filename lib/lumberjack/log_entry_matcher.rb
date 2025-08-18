# frozen_string_literal: true

module Lumberjack
  class LogEntryMatcher
    def initialize(message: nil, severity: nil, progname: nil, attributes: nil)
      @message_filter = message
      @severity_filter = Severity.coerce(severity) if severity
      @progname_filter = progname
      @attributes_filter = Utils.expand_attributes(attributes) if attributes
    end

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

    def match_filter?(value, filter)
      return true if filter.nil?

      filter === value
    end

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
