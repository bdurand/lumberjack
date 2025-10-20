# frozen_string_literal: true

module Lumberjack
  class Formatter
    # Format a Date, Time, or DateTime object. If you don't specify a format in the constructor, it will use
    # the ISO-8601 format with microsecond precision. This formatter provides consistent date/time representation
    # across your application logs.
    class DateTimeFormatter
      FormatterRegistry.add(:date_time, self)

      # @!attribute [r] format
      #   @return [String, nil] The strftime format string, or nil for ISO-8601 default.
      attr_reader :format

      # @param format [String, nil] The format to use when formatting the date/time object.
      #   If nil, uses ISO-8601 format with microsecond precision.
      def initialize(format = nil)
        @format = format.dup.to_s.freeze unless format.nil?
      end

      # Format a date/time object using the configured format.
      #
      # @param obj [Date, Time, DateTime, Object] The object to format. Should respond to
      #   strftime (for custom format) or iso8601 (for default format).
      # @return [String] The formatted date/time string.
      def call(obj)
        if @format && obj.respond_to?(:strftime)
          obj.strftime(@format)
        elsif obj.respond_to?(:iso8601)
          obj.iso8601(6)
        else
          obj.to_s
        end
      end
    end
  end
end
