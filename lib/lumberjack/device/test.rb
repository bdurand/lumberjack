# frozen_string_literal: true

module Lumberjack
  class Device
    # This is a logging device that captures entries in memory for testing purposes.
    # You can set the logger device to a test device and then make assertions about
    # the captured log entries.
    #
    # @example
    #   logger = Lumberjack::Logger.new(:test)
    #   logger.info("Test message", attributes: {foo: "bar"})
    #   expect(logger.device).to include(severity: :info, message: /Test/)
    #   expect(logger.device).to include(attributes: {foo: "bar"})
    class Test < Device
      attr_accessor :max_entries

      # Options passed to the constructor. These don't serve any purpose but can be used
      # in tests to verify that options are passed through correctly when creating devices.
      attr_reader :options

      # @param options [Hash] The options for the test device.
      # @option max_entries [Integer] The maximum number of entries to capture. Defaults to 1000.
      def initialize(options = {})
        @buffer = []
        @max_entries = options[:max_entries] || 1000
        @lock = Mutex.new
        @options = options.dup
      end

      def write(entry)
        return if max_entries < 1

        @lock.synchronize do
          @buffer << entry

          while @buffer.size > max_entries
            @buffer.shift
          end
        end
      end

      # Return the list of captured log entries.
      #
      # @return [Array<Lumberjack::LogEntry>] The captured log entries.
      def entries
        @lock.synchronize { @buffer.dup }
      end

      # Return the last log entry.
      #
      # @return [Lumberjack::LogEntry, nil] The last log entry or nil if no entries exist.
      def last_entry
        @buffer.last
      end

      # Clears the captured log entries.
      #
      # @return [void]
      def flush
        @buffer = []
      end

      # Return true if the captured log entries match the specified level, message, and attributes.
      #
      # For level, you can specified either a numeric constant (i.e. `Logger::WARN`) or a symbol
      # (i.e. `:warn`).
      #
      # For message you can specify a string to perform an exact match or a regular expression
      # to perform a partial or pattern match. You can also supply any matcher value available
      # in your test library (i.e. in rspec you could use `anything` or `instance_of(Error)`, etc.).
      #
      # For attributes, you can specify a hash of tag names to values to match. You can use
      # regular expression or matchers as the values here as well. attributes can also be nested to match
      # nested attributes.
      #
      # Example:
      #
      # ```
      # logs.include(level: :warn, message: /something happened/, attributes: {duration: Float})
      # ```
      #
      # @param options [Hash] The options to match against the log entries.
      # @option options [String, Regexp] :message The message to match against the log entries.
      # @option options [String, Symbol, Integer] :severity The log level to match against the log entries.
      # @option options [Hash] :attributes A hash of tag names to values to match against the log entries. The attributes
      #   will match nested attributes using dot notation (e.g. `foo.bar` will match a tag with the structure
      #   `{foo: {bar: "value"}}`).
      # @option options [String, Regexp] :progname The program name to match against the log entries.
      # @return [Boolean] True if any entries match the specified filters, false otherwise.
      def include?(options)
        options = options.transform_keys(&:to_sym)
        !!match(**options)
      end

      # Return the first entry that matches the specified filters.
      #
      # @param message [String, Regexp, nil] The message to match against the log entries.
      # @param severity [String, Symbol, Integer, nil] The log level to match against the log entries.
      # @param attributes [Hash, nil] A hash of tag names to values to match against the log entries.
      # @param progname [String, nil] The program name to match against the log entries.
      # @return [Lumberjack::LogEntry, nil] The log entry that most closely matches the filters, or nil if no entry meets minimum criteria.
      def match(message: nil, severity: nil, attributes: nil, progname: nil)
        matcher = LogEntryMatcher.new(message: message, severity: severity, attributes: attributes, progname: progname)
        entries.detect { |entry| matcher.match?(entry) }
      end
    end
  end
end
