# frozen_string_literal: true

module Lumberjack
  class LogEntryMatcher
    def initialize(message: nil, severity: nil, progname: nil, tags: nil)
      @message_filter = message
      @severity_filter = Severity.coerce(severity) if severity
      @progname_filter = progname
      @tags_filter = Utils.expand_tags(tags) if tags
    end

    def match?(entry)
      return false unless match_filter?(entry.message, @message_filter)
      return false unless match_filter?(entry.severity, @severity_filter)
      return false unless match_filter?(entry.progname, @progname_filter)

      if @tags_filter
        tags = Utils.expand_tags(entry.tags)
        return false unless match_tags?(tags, @tags_filter)
      end

      true
    end

    private

    def match_filter?(value, filter)
      return true if filter.nil?

      filter === value
    end

    def match_tags?(tags, filter)
      return true unless filter
      return false unless tags

      filter.all? do |name, value_filter|
        name = name.to_s
        tag_values = tags[name]
        if tag_values.is_a?(Hash)
          if value_filter.is_a?(Hash)
            match_tags?(tag_values, value_filter)
          else
            match_filter?(tag_values, value_filter)
          end
        elsif value_filter.nil? || (value_filter.is_a?(Enumerable) && value_filter.empty?)
          tag_values.nil? || (tag_values.is_a?(Array) && tag_values.empty?)
        elsif tags.include?(name)
          match_filter?(tag_values, value_filter)
        else
          false
        end
      end
    end
  end
end
