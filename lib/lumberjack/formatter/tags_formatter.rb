# frozen_string_literal: true

module Lumberjack
  # This formatter is designed to output tags in a specific format.
  #
  # - Simple values will be formatted as "[value]"
  # - Arrays will be formatted as "[value1] [value2] [value3]"
  # - Hashes will be formatted as "[key1=value1] [key2=value2]"
  # - Hashes in arrays will be formatted as "[key=value]"
  class Formatter::TagsFormatter
    def call(tags)
      tags = tags.collect { |key, value| "#{key}=#{value}" } if tags.is_a?(Hash)
      if tags.is_a?(Array)
        tags.collect { |tag| format_tag(tag) }.join(" ") unless tags.empty?
      else
        format_tag(tags)
      end
    end

    private

    def format_tag(tag)
      if tag.is_a?(Hash)
        tag.collect { |key, value| "[#{key}=#{value.strip}]" }.join(" ")
      else
        "[#{tag.strip}]"
      end
    end
  end
end
