# frozen_string_literal: true

module Lumberjack
  # An in-memory logging device designed specifically for testing and debugging
  # scenarios. This device captures log entries in a thread-safe buffer, allowing
  # test code to make assertions about logged content, verify logging behavior,
  # and inspect log entry details without writing to external outputs.
  #
  # The device provides sophisticated matching capabilities through integration
  # with LogEntryMatcher, supporting pattern matching on messages, severity levels,
  # attributes, and program names. This makes it ideal for comprehensive logging
  # verification in test suites.
  #
  # The buffer is automatically managed with configurable size limits to prevent
  # memory issues during long-running tests, and provides both individual entry
  # access and bulk matching operations.
  #
  # @example Basic test setup
  #   logger = Lumberjack::Logger.new(Lumberjack::Device::Test.new)
  #   logger.info("User logged in", user_id: 123)
  #
  #   expect(logger.device.entries.size).to eq(1)
  #   expect(logger.device.last_entry.message).to eq("User logged in")
  #
  # @example Using convenience constructor
  #   logger = Lumberjack::Logger.new(:test)
  #   logger.warn("Something suspicious", ip: "192.168.1.100")
  #
  #   expect(logger.device).to include(severity: :warn, message: /suspicious/)
  #   expect(logger.device).to include(attributes: {ip: "192.168.1.100"})
  #
  # @example Advanced pattern matching
  #   logger = Lumberjack::Logger.new(:test)
  #   logger.error("Database error: connection timeout",
  #                database: "users", timeout: 30.5, retry_count: 3)
  #
  #   expect(logger.device).to include(
  #     severity: :error,
  #     message: /Database error/,
  #     attributes: {
  #       database: "users",
  #       timeout: Float,
  #       retry_count: be > 0
  #     }
  #   )
  #
  # @example Nested attribute matching
  #   logger.info("Request completed", request: {method: "POST", path: "/users"})
  #
  #   expect(logger.device).to include(
  #     attributes: {"request.method" => "POST", "request.path" => "/users"}
  #   )
  #
  # @see LogEntryMatcher
  class Device::Test < Device
    # @!attribute [rw] max_entries
    #   @return [Integer] The maximum number of entries to retain in the buffer
    attr_accessor :max_entries

    # Configuration options passed to the constructor. While these don't affect
    # device behavior, they can be useful in tests to verify that options are
    # correctly passed through device creation and configuration pipelines.
    #
    # @return [Hash] A copy of the options hash passed during initialization
    attr_reader :options

    # Initialize a new Test device with configurable buffer management.
    # The device creates a thread-safe in-memory buffer for capturing log
    # entries with automatic size management to prevent memory issues.
    #
    # @param options [Hash] Configuration options for the test device
    # @option options [Integer] :max_entries (1000) The maximum number of entries
    #   to retain in the buffer. When this limit is exceeded, the oldest entries
    #   are automatically removed to maintain the size limit.
    def initialize(options = {})
      @buffer = []
      @max_entries = options[:max_entries] || 1000
      @lock = Mutex.new
      @options = options.dup
    end

    # Write a log entry to the in-memory buffer. The method is thread-safe and
    # automatically manages buffer size by removing the oldest entries when
    # the maximum capacity is exceeded. Entries are ignored if max_entries is
    # set to less than 1.
    #
    # @param entry [Lumberjack::LogEntry] The log entry to store in the buffer
    # @return [void]
    def write(entry)
      return if max_entries < 1

      @lock.synchronize do
        @buffer << entry

        while @buffer.size > max_entries
          @buffer.shift
        end
      end
    end

    # Return a thread-safe copy of all captured log entries. The returned array
    # is a snapshot of the current buffer state and can be safely modified
    # without affecting the internal buffer.
    #
    # @return [Array<Lumberjack::LogEntry>] A copy of all captured log entries
    #   in chronological order (oldest first)
    def entries
      @lock.synchronize { @buffer.dup }
    end

    # Return the most recently captured log entry. This provides quick access
    # to the latest logged information without needing to access the full
    # entries array.
    #
    # @return [Lumberjack::LogEntry, nil] The most recent log entry, or nil
    #   if no entries have been captured yet
    def last_entry
      @buffer.last
    end

    # Clear all captured log entries from the buffer. This method is useful
    # for resetting the device state between tests or when you want to start
    # fresh log capture without creating a new device instance.
    #
    # @return [void]
    def flush
      @buffer = []
    end

    # Test whether any captured log entries match the specified criteria.
    # This method provides a convenient interface for making assertions about
    # logged content using flexible pattern matching capabilities.
    #
    # Severity can be specified as a numeric constant (Logger::WARN), symbol
    # (:warn), or string ("warn"). Messages support exact string matching or
    # regular expression patterns. Attributes support nested matching using
    # dot notation and can use any matcher values supported by your test
    # framework (e.g., RSpec's `anything`, `instance_of`, etc.).
    #
    # @param options [Hash] The matching criteria to test against captured entries
    # @option options [String, Regexp, Object] :message Pattern to match against
    #   log entry messages. Supports exact strings, regular expressions, or any
    #   object that responds to case equality (===)
    # @option options [String, Symbol, Integer] :severity The severity level to
    #   match. Accepts symbols (:debug, :info, :warn, :error, :fatal), strings,
    #   or numeric Logger constants
    # @option options [Hash] :attributes Hash of attribute patterns to match.
    #   Supports nested attributes using dot notation (e.g., "user.id" matches
    #   {user: {id: value}}). Values can be exact matches or test framework matchers
    # @option options [String, Regexp, Object] :progname Pattern to match against
    #   the program name that generated the log entry
    #
    # @return [Boolean] True if any captured entries match all specified criteria,
    #   false otherwise
    #
    # @example Basic message and severity matching
    #   expect(device).to include(severity: :error, message: "Database connection failed")
    #
    # @example Regular expression message matching
    #   expect(device).to include(severity: :info, message: /User \d+ logged in/)
    #
    # @example Attribute matching with exact values
    #   expect(device).to include(attributes: {user_id: 123, action: "login"})
    #
    # @example Nested attribute matching
    #   expect(device).to include(attributes: {"request.method" => "POST", "response.status" => 200})
    #
    # @example Using test framework matchers (RSpec example)
    #   expect(device).to include(
    #     severity: :warn,
    #     message: start_with("Warning:"),
    #     attributes: {duration: be_a(Float), retries: be > 0}
    #   )
    #
    # @example Multiple criteria matching
    #   expect(device).to include(
    #     severity: :error,
    #     message: /timeout/i,
    #     progname: "DatabaseWorker",
    #     attributes: {database: "users", timeout_seconds: be > 30}
    #   )
    def include?(options)
      options = options.transform_keys(&:to_sym)
      !!match(**options)
    end

    # Find and return the first captured log entry that matches the specified
    # criteria. This method is useful when you need to inspect specific entry
    # details or perform more complex assertions on individual entries.
    #
    # Uses the same flexible matching capabilities as include? but returns
    # the actual LogEntry object instead of a boolean result.
    #
    # @param message [String, Regexp, Object, nil] Pattern to match against
    #   log entry messages. Supports exact strings, regular expressions, or
    #   any object that responds to case equality (===)
    # @param severity [String, Symbol, Integer, nil] The severity level to match.
    #   Accepts symbols, strings, or numeric Logger constants
    # @param attributes [Hash, nil] Hash of attribute patterns to match against
    #   log entry attributes. Supports nested matching using dot notation
    # @param progname [String, Regexp, Object, nil] Pattern to match against
    #   the program name that generated the log entry
    #
    # @return [Lumberjack::LogEntry, nil] The first matching log entry, or nil
    #   if no entries match the specified criteria
    #
    # @example Finding a specific error entry
    #   error_entry = device.match(severity: :error, message: /database/i)
    #   expect(error_entry.attributes[:table_name]).to eq("users")
    #   expect(error_entry.time).to be_within(1.second).of(Time.now)
    #
    # @example Finding entries with specific attributes
    #   auth_entry = device.match(attributes: {user_id: 123, action: "login"})
    #   expect(auth_entry.severity_label).to eq("INFO")
    #   expect(auth_entry.progname).to eq("AuthService")
    #
    # @example Handling no matches
    #   missing_entry = device.match(severity: :fatal)
    #   expect(missing_entry).to be_nil
    #
    # @example Complex attribute matching
    #   api_entry = device.match(
    #     message: /API request/,
    #     attributes: {"request.endpoint" => "/users", "response.status" => 200}
    #   )
    #   expect(api_entry.attributes["request.method"]).to eq("GET")
    def match(message: nil, severity: nil, attributes: nil, progname: nil)
      matcher = LogEntryMatcher.new(message: message, severity: severity, attributes: attributes, progname: progname)
      entries.detect { |entry| matcher.match?(entry) }
    end
  end
end
