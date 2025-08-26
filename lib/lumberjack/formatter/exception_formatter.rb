# frozen_string_literal: true

module Lumberjack
  class Formatter
    # Format an exception including the backtrace. You can specify an object that
    # responds to `call` as a backtrace cleaner. The exception backtrace will be
    # passed to this object and the returned array is what will be logged. You can
    # use this to clean out superfluous lines.
    class ExceptionFormatter
      FormatterRegistry.add(:exception, self)

      # @!attribute [rw] backtrace_cleaner
      #   @return [#call, nil] An object that responds to `call` and takes
      #     an array of strings (the backtrace) and returns an array of strings.
      attr_accessor :backtrace_cleaner

      # @param backtrace_cleaner [#call, nil] An object that responds to `call` and takes
      #   an array of strings (the backtrace) and returns an array of strings (the
      #   cleaned backtrace).
      def initialize(backtrace_cleaner = nil)
        self.backtrace_cleaner = backtrace_cleaner
      end

      # Format an exception with its message and backtrace.
      #
      # @param exception [Exception] The exception to format.
      # @return [String] The formatted exception with class name, message, and backtrace.
      def call(exception)
        message = +"#{exception.class.name}: #{exception.message}"
        trace = exception.backtrace
        if trace
          trace = clean_backtrace(trace)
          message << "#{Lumberjack::LINE_SEPARATOR}  #{trace.join("#{Lumberjack::LINE_SEPARATOR}  ")}"
        end
        message
      end

      private

      def clean_backtrace(trace)
        if trace && backtrace_cleaner
          backtrace_cleaner.call(trace)
        else
          trace
        end
      end
    end
  end
end
