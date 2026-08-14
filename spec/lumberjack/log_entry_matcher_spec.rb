# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::LogEntryMatcher do
  describe "#match?" do
    let(:entry) { Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Test message", "AppName", Process.pid, attributes) }
    let(:attributes) { {} }

    describe "severity filter" do
      it "matches if the severity is equal" do
        matcher = Lumberjack::LogEntryMatcher.new(severity: Logger::INFO)
        expect(matcher.match?(entry)).to be true
      end

      it "matches if the severity is equal using a severity name" do
        matcher = Lumberjack::LogEntryMatcher.new(severity: :info)
        expect(matcher.match?(entry)).to be true
      end

      it "does not match if the severity is not equal" do
        matcher = Lumberjack::LogEntryMatcher.new(severity: Logger::ERROR)
        expect(matcher.match?(entry)).to be false
      end
    end

    describe "message filter" do
      it "matches if the messages are equal" do
        matcher = Lumberjack::LogEntryMatcher.new(message: "Test message")
        expect(matcher.match?(entry)).to be true
      end

      it "does not match if the messages are not equal" do
        matcher = Lumberjack::LogEntryMatcher.new(message: "Different message")
        expect(matcher.match?(entry)).to be false
      end

      it "matches if the message matches a pattern" do
        matcher = Lumberjack::LogEntryMatcher.new(message: /Test/)
        expect(matcher.match?(entry)).to be true
      end

      it "does not match if the message does not match the pattern" do
        matcher = Lumberjack::LogEntryMatcher.new(message: /Different/)
        expect(matcher.match?(entry)).to be false
      end

      it "matches if the message matches the class" do
        matcher = Lumberjack::LogEntryMatcher.new(message: String)
        expect(matcher.match?(entry)).to be true
      end

      it "strips leading and trailing whitespace from string message filters" do
        matcher = Lumberjack::LogEntryMatcher.new(message: "  Test message\n")
        expect(matcher.match?(entry)).to be true
      end
    end

    describe "progname filter" do
      it "matches if the progname is equal" do
        matcher = Lumberjack::LogEntryMatcher.new(progname: "AppName")
        expect(matcher.match?(entry)).to be true
      end

      it "does not match if the progname is not equal" do
        matcher = Lumberjack::LogEntryMatcher.new(progname: "DifferentApp")
        expect(matcher.match?(entry)).to be false
      end

      it "matches if the progname matches a pattern" do
        matcher = Lumberjack::LogEntryMatcher.new(progname: /App/)
        expect(matcher.match?(entry)).to be true
      end

      it "does not match if the progname does not match the pattern" do
        matcher = Lumberjack::LogEntryMatcher.new(progname: /Different/)
        expect(matcher.match?(entry)).to be false
      end

      it "matches if the progname matches the class" do
        matcher = Lumberjack::LogEntryMatcher.new(progname: String)
        expect(matcher.match?(entry)).to be true
      end
    end

    describe "attributes filter" do
      it "matches if the attribute is equal" do
        attributes["key"] = "value"
        matcher = Lumberjack::LogEntryMatcher.new(attributes: {key: "value"})
        expect(matcher.match?(entry)).to be true
      end

      it "does not match if the attribute is not equal" do
        attributes["key"] = "value"
        matcher = Lumberjack::LogEntryMatcher.new(attributes: {key: "different"})
        expect(matcher.match?(entry)).to be false
      end

      it "matches if the attribute matches a pattern" do
        attributes["key"] = "value"
        matcher = Lumberjack::LogEntryMatcher.new(attributes: {key: /val/})
        expect(matcher.match?(entry)).to be true
      end

      it "does not match if the attribute does not match the pattern" do
        attributes["key"] = "value"
        matcher = Lumberjack::LogEntryMatcher.new(attributes: {key: /different/})
        expect(matcher.match?(entry)).to be false
      end

      it "matches if the attribute matches the class" do
        attributes["key"] = 14
        matcher = Lumberjack::LogEntryMatcher.new(attributes: {key: Integer})
        expect(matcher.match?(entry)).to be true
      end

      it "does not match if the attribute does not match the class" do
        attributes["key"] = 14
        matcher = Lumberjack::LogEntryMatcher.new(attributes: {key: String})
        expect(matcher.match?(entry)).to be false
      end

      it "does not match if the attribute does not exist" do
        attributes["key"] = "value"
        matcher = Lumberjack::LogEntryMatcher.new(attributes: {other_key: "nonexistent"})
        expect(matcher.match?(entry)).to be false
      end

      it "matches if all attributes match" do
        attributes["key_1"] = "value 1"
        attributes["key_2"] = "value 2"
        matcher = Lumberjack::LogEntryMatcher.new(attributes: {key_1: "value 1", key_2: "value 2"})
        expect(matcher.match?(entry)).to be true
      end

      it "does not match if any values do not match" do
        attributes["key_1"] = "value 1"
        attributes["key_2"] = "value 2"
        matcher = Lumberjack::LogEntryMatcher.new(attributes: {key_1: "value 1", key_2: "different"})
        expect(matcher.match?(entry)).to be false
      end

      it "matches a nil only if the attribute does not exist" do
        attributes["key"] = "value"
        expect(Lumberjack::LogEntryMatcher.new(attributes: {key: nil}).match?(entry)).to be false
        expect(Lumberjack::LogEntryMatcher.new(attributes: {other_key: nil}).match?(entry)).to be true
      end

      it "matches an empty array only if the attribute does not exist" do
        attributes["key"] = "value"
        expect(Lumberjack::LogEntryMatcher.new(attributes: {key: []}).match?(entry)).to be false
        expect(Lumberjack::LogEntryMatcher.new(attributes: {other_key: []}).match?(entry)).to be true
      end

      it "matches dot notation on attribute filters" do
        attributes["foo.bar.baz"] = "boo"
        expect(Lumberjack::LogEntryMatcher.new(attributes: {"foo.bar" => {"baz" => "boo"}}).match?(entry)).to be true
        expect(Lumberjack::LogEntryMatcher.new(attributes: {"foo.bar" => {"baz" => "bip"}}).match?(entry)).to be false
        expect(Lumberjack::LogEntryMatcher.new(attributes: {"foo.bar" => Hash}).match?(entry)).to be true
        expect(Lumberjack::LogEntryMatcher.new(attributes: {"foo.bar" => String}).match?(entry)).to be false
      end

      it "matches nested attribute filters" do
        attributes["foo.bar.baz"] = "boo"
        attributes["foo.bar.bip"] = "bop"
        expect(Lumberjack::LogEntryMatcher.new(attributes: {foo: {bar: {baz: "boo"}}}).match?(entry)).to be true
        expect(Lumberjack::LogEntryMatcher.new(attributes: {foo: {bar: {baz: "boo", bip: /b/}}}).match?(entry)).to be true
        expect(Lumberjack::LogEntryMatcher.new(attributes: {foo: {bar: {baz: "boo", bip: /c/}}}).match?(entry)).to be false
        expect(Lumberjack::LogEntryMatcher.new(attributes: {foo: {"bar.baz": "boo"}}).match?(entry)).to be true
      end

      it "should match arrays of hashes" do
        attributes["foo"] = [{bar: "baz"}, {bip: "bop"}]
        expect(Lumberjack::LogEntryMatcher.new(attributes: {foo: [{bar: "baz"}, {bip: "bop"}]}).match?(entry)).to be true
        expect(Lumberjack::LogEntryMatcher.new(attributes: {foo: [{bar: "baz"}]}).match?(entry)).to be false
      end

      it "does not match an entry with no attributes" do
        entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Test message", nil, nil, nil)
        matcher = Lumberjack::LogEntryMatcher.new(attributes: {key: "value"})
        expect(matcher.match?(entry)).to be false
      end

      it "matches a hash matcher against a nested attribute" do
        attributes["foo.bar"] = "baz"
        attributes["foo.bip"] = "bop"
        expect(Lumberjack::LogEntryMatcher.new(attributes: {foo: hash_including("bar" => "baz")}).match?(entry)).to be true
        expect(Lumberjack::LogEntryMatcher.new(attributes: {foo: hash_including("bar" => "boo")}).match?(entry)).to be false
        expect(Lumberjack::LogEntryMatcher.new(attributes: {foo: hash_including("nope" => "baz")}).match?(entry)).to be false
        expect(Lumberjack::LogEntryMatcher.new(attributes: {nope: hash_including("bar" => "baz")}).match?(entry)).to be false
      end

      it "matches a hash matcher against the entire attributes hash" do
        attributes["foo.bar"] = "baz"
        attributes["key"] = "value"
        expect(Lumberjack::LogEntryMatcher.new(attributes: hash_including("foo" => {"bar" => "baz"})).match?(entry)).to be true
        expect(Lumberjack::LogEntryMatcher.new(attributes: hash_including("foo" => {"bar" => "boo"})).match?(entry)).to be false
        expect(Lumberjack::LogEntryMatcher.new(attributes: hash_including("nope" => "baz")).match?(entry)).to be false
        expect(Lumberjack::LogEntryMatcher.new(attributes: hash_including("key" => "value")).match?(entry)).to be true
      end

      it "allows hash matchers to use either string or symbol keys" do
        attributes["foo.bar"] = "baz"
        expect(Lumberjack::LogEntryMatcher.new(attributes: hash_including(foo: {bar: "baz"})).match?(entry)).to be true
        expect(Lumberjack::LogEntryMatcher.new(attributes: hash_including(foo: {bar: "boo"})).match?(entry)).to be false
        expect(Lumberjack::LogEntryMatcher.new(attributes: hash_including(nope: "baz")).match?(entry)).to be false
        expect(Lumberjack::LogEntryMatcher.new(attributes: {foo: hash_including(bar: "baz")}).match?(entry)).to be true
        expect(Lumberjack::LogEntryMatcher.new(attributes: {foo: hash_including(bar: "boo")}).match?(entry)).to be false
        expect(Lumberjack::LogEntryMatcher.new(attributes: {foo: hash_including(nope: "baz")}).match?(entry)).to be false
      end
    end

    describe "multiple filters" do
      it "matches if all filters match" do
        matcher = Lumberjack::LogEntryMatcher.new(message: /Test/, progname: "AppName")
        expect(matcher.match?(entry)).to be true
      end

      it "does not match if any filters do not match" do
        matcher = Lumberjack::LogEntryMatcher.new(message: /Test/, progname: "DifferentApp")
        expect(matcher.match?(entry)).to be false
      end
    end
  end

  describe "#diff" do
    let(:entry) { Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Test message", "AppName", Process.pid, attributes) }
    let(:attributes) { {} }

    it "returns an empty hash when the entry matches" do
      matcher = Lumberjack::LogEntryMatcher.new(message: "Test message", severity: :info, progname: "AppName")
      expect(matcher.diff(entry)).to eq({})
    end

    it "returns an empty hash when the matcher has no filters" do
      expect(Lumberjack::LogEntryMatcher.new.diff(entry)).to eq({})
    end

    it "reports a message mismatch with the raw filter value" do
      matcher = Lumberjack::LogEntryMatcher.new(message: /Different/)
      expect(matcher.diff(entry)).to eq({"message" => {expected: /Different/, actual: "Test message"}})
    end

    it "reports a severity mismatch using severity labels" do
      matcher = Lumberjack::LogEntryMatcher.new(severity: :error)
      expect(matcher.diff(entry)).to eq({"severity" => {expected: "ERROR", actual: "INFO"}})
    end

    it "reports a progname mismatch" do
      matcher = Lumberjack::LogEntryMatcher.new(progname: "OtherApp")
      expect(matcher.diff(entry)).to eq({"progname" => {expected: "OtherApp", actual: "AppName"}})
    end

    it "reports multiple mismatched fields" do
      matcher = Lumberjack::LogEntryMatcher.new(message: "Other", severity: :error, progname: "AppName")
      expect(matcher.diff(entry)).to eq({
        "message" => {expected: "Other", actual: "Test message"},
        "severity" => {expected: "ERROR", actual: "INFO"}
      })
    end

    it "reports attribute mismatches using dot notation keys" do
      attributes["key"] = "value"
      attributes["error.kind"] = "RuntimeError"
      matcher = Lumberjack::LogEntryMatcher.new(attributes: {key: "value", error: {kind: "ArgumentError"}})
      expect(matcher.diff(entry)).to eq({"attributes" => {"error.kind" => {expected: "ArgumentError", actual: "RuntimeError"}}})
    end

    it "reports a missing attribute with a nil actual value" do
      matcher = Lumberjack::LogEntryMatcher.new(attributes: {key: "value"})
      expect(matcher.diff(entry)).to eq({"attributes" => {"key" => {expected: "value", actual: nil}}})
    end

    it "reports an attribute that was expected to be absent" do
      attributes["key"] = "value"
      matcher = Lumberjack::LogEntryMatcher.new(attributes: {key: nil})
      expect(matcher.diff(entry)).to eq({"attributes" => {"key" => {expected: nil, actual: "value"}}})
    end

    it "reports an attribute that was expected to be empty" do
      attributes["key"] = ["value"]
      matcher = Lumberjack::LogEntryMatcher.new(attributes: {key: []})
      expect(matcher.diff(entry)).to eq({"attributes" => {"key" => {expected: [], actual: ["value"]}}})
    end

    it "reports a hash filter against a non hash value as a single mismatch" do
      attributes["key"] = "value"
      matcher = Lumberjack::LogEntryMatcher.new(attributes: {key: {nested: 1}})
      expect(matcher.diff(entry)).to eq({"attributes" => {"key" => {expected: {"nested" => 1}, actual: "value"}}})
    end

    it "reports a failed matcher applied to the entire attributes hash as a single mismatch" do
      attributes["key"] = "value"
      hash_matcher = hash_including("other" => "value")
      matcher = Lumberjack::LogEntryMatcher.new(attributes: hash_matcher)
      expect(matcher.diff(entry)).to eq({"attributes" => {expected: hash_matcher, actual: {"key" => "value"}}})
    end

    it "returns an empty hash when a matcher applied to the entire attributes hash matches" do
      attributes["key"] = "value"
      matcher = Lumberjack::LogEntryMatcher.new(attributes: hash_including("key" => "value"))
      expect(matcher.diff(entry)).to eq({})
    end

    it "reports a failed matcher on a nested attribute keyed by its dot notation name" do
      attributes["foo.bar"] = "baz"
      hash_matcher = hash_including("bar" => "boo")
      matcher = Lumberjack::LogEntryMatcher.new(attributes: {foo: hash_matcher})
      expect(matcher.diff(entry)).to eq({"attributes" => {"foo" => {expected: hash_matcher, actual: {"bar" => "baz"}}}})
    end

    it "is empty exactly when the entry matches" do
      attributes["key"] = "value"
      matchers = [
        Lumberjack::LogEntryMatcher.new(message: "Test message", attributes: {key: "value"}),
        Lumberjack::LogEntryMatcher.new(message: "Other"),
        Lumberjack::LogEntryMatcher.new(severity: :error, progname: "Nope"),
        Lumberjack::LogEntryMatcher.new(attributes: {key: "other"}),
        Lumberjack::LogEntryMatcher.new(attributes: {other: nil}),
        Lumberjack::LogEntryMatcher.new(attributes: hash_including("key" => "value"))
      ]
      matchers.each do |matcher|
        expect(matcher.diff(entry).empty?).to eq matcher.match?(entry)
      end
    end
  end

  describe "formatter matching" do
    let(:entry_formatter) do
      Lumberjack::EntryFormatter.build do |config|
        config.format_message(Exception) do |e|
          Lumberjack::MessageAttributes.new(e.inspect, {error: {kind: e.class.name, message: e.message, trace: e.backtrace}})
        end
        config.format_attributes(Exception) do |e|
          {kind: e.class.name, message: e.message, trace: e.backtrace}
        end
      end
    end

    let(:exception) do
      raise "boom"
    rescue => e
      e
    end

    let(:entry) do
      logger = Lumberjack::Logger.new(:test, formatter: entry_formatter)
      logger.error(exception)
      logger.device.last_entry
    end

    it "matches an unformatted message filter against the formatted message" do
      matcher = Lumberjack::LogEntryMatcher.new(message: exception, formatter: entry_formatter)
      expect(matcher.match?(entry)).to be true
    end

    it "matches an unformatted attribute filter against the formatted attributes" do
      matcher = Lumberjack::LogEntryMatcher.new(
        message: exception.inspect,
        attributes: {error: exception},
        formatter: entry_formatter
      )
      expect(matcher.match?(entry)).to be true
    end

    it "matches fully expanded attribute filters" do
      matcher = Lumberjack::LogEntryMatcher.new(
        message: exception.inspect,
        attributes: {error: {kind: exception.class.name, message: exception.message, trace: exception.backtrace}},
        formatter: entry_formatter
      )
      expect(matcher.match?(entry)).to be true
    end

    it "does not match when the formatted values are different" do
      other = RuntimeError.new("different")
      matcher = Lumberjack::LogEntryMatcher.new(message: other, formatter: entry_formatter)
      expect(matcher.match?(entry)).to be false

      matcher = Lumberjack::LogEntryMatcher.new(attributes: {error: other}, formatter: entry_formatter)
      expect(matcher.match?(entry)).to be false
    end

    it "matches an exception without a backtrace against an entry without a trace attribute" do
      quiet_exception = RuntimeError.new("quiet")
      logger = Lumberjack::Logger.new(:test, formatter: entry_formatter)
      logger.error(quiet_exception)
      quiet_entry = logger.device.last_entry

      matcher = Lumberjack::LogEntryMatcher.new(attributes: {error: quiet_exception}, formatter: entry_formatter)
      expect(matcher.match?(quiet_entry)).to be true
    end

    it "does not invoke the formatter when the raw value matches" do
      calls = 0
      formatter = Lumberjack::EntryFormatter.build do |config|
        config.format_message(String) do |value|
          calls += 1
          value
        end
      end
      plain_entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Test message", nil, nil, {})
      matcher = Lumberjack::LogEntryMatcher.new(message: "Test message", formatter: formatter)
      expect(matcher.match?(plain_entry)).to be true
      expect(calls).to eq 0
    end

    it "formats a filter value only once when matching multiple entries" do
      calls = 0
      formatter = Lumberjack::EntryFormatter.build do |config|
        config.format_message(Symbol) do |value|
          calls += 1
          value.to_s
        end
      end
      plain_entries = Array.new(3) { |i| Lumberjack::LogEntry.new(Time.now, Logger::INFO, "message #{i}", nil, nil, {}) }
      matcher = Lumberjack::LogEntryMatcher.new(message: :other, formatter: formatter)
      plain_entries.each { |plain_entry| matcher.match?(plain_entry) }
      expect(calls).to eq 1
    end

    it "applies attribute name formatters to filter values using dot notation names" do
      formatter = Lumberjack::EntryFormatter.build do |config|
        config.format_attribute_name("user.id") { |value| value.to_s.rjust(5, "0") }
      end
      plain_entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Test", nil, nil, {"user.id" => "00042"})
      matcher = Lumberjack::LogEntryMatcher.new(attributes: {user: {id: 42}}, formatter: formatter)
      expect(matcher.match?(plain_entry)).to be true
    end

    it "does not format values inside an already formatted attribute filter" do
      formatter = Lumberjack::EntryFormatter.build do |config|
        config.format_message(Exception, &:inspect)
        config.format_attributes(Exception) { |e| {kind: e.class.name, message: e.message} }
        config.format_attributes(String) { |s| "str:#{s}" }
      end
      logger = Lumberjack::Logger.new(:test, formatter: formatter)
      logger.error("error", error: exception)
      formatted_entry = logger.device.last_entry

      matcher = Lumberjack::LogEntryMatcher.new(attributes: {error: exception}, formatter: formatter)
      expect(matcher.match?(formatted_entry)).to be true
    end

    it "does not format pattern filters" do
      formatter = Lumberjack::EntryFormatter.build do |config|
        config.format_attributes(Numeric, &:to_s)
      end
      plain_entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Test message", nil, nil, {"count" => 5, "name" => "test"})

      expect(Lumberjack::LogEntryMatcher.new(message: /Test/, formatter: formatter).match?(plain_entry)).to be true
      expect(Lumberjack::LogEntryMatcher.new(attributes: {count: be > 1}, formatter: formatter).match?(plain_entry)).to be true
      expect(Lumberjack::LogEntryMatcher.new(attributes: {count: be > 10}, formatter: formatter).match?(plain_entry)).to be false
      expect(Lumberjack::LogEntryMatcher.new(attributes: hash_including("name" => "test"), formatter: formatter).match?(plain_entry)).to be true
    end

    it "does not format severity or progname filters" do
      formatter = Lumberjack::EntryFormatter.build do |config|
        config.format_message(Symbol, &:to_s)
      end
      plain_entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Test message", "AppName", nil, {})
      matcher = Lumberjack::LogEntryMatcher.new(progname: :AppName, formatter: formatter)
      expect(matcher.match?(plain_entry)).to be false
    end

    it "does not raise when a formatter raises an error" do
      save_stderr = $stderr
      begin
        $stderr = StringIO.new
        formatter = Lumberjack::EntryFormatter.build do |config|
          config.format_message(Symbol) { |value| raise "formatter error" }
        end
        plain_entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Test message", nil, nil, {})
        matcher = Lumberjack::LogEntryMatcher.new(message: :other, formatter: formatter)
        expect(matcher.match?(plain_entry)).to be false
      ensure
        $stderr = save_stderr
      end
    end

    it "accepts a logger as the formatter" do
      logger = Lumberjack::Logger.new(:test, formatter: entry_formatter)
      logger.error(exception)
      matcher = Lumberjack::LogEntryMatcher.new(message: exception, formatter: logger)
      expect(matcher.match?(logger.device.last_entry)).to be true
    end

    it "raises an ArgumentError when the formatter is not an EntryFormatter or Logger" do
      expect {
        Lumberjack::LogEntryMatcher.new(message: "test", formatter: "bogus")
      }.to raise_error(ArgumentError)
    end

    it "returns an empty diff when the entry matches through formatting" do
      matcher = Lumberjack::LogEntryMatcher.new(message: exception, attributes: {error: exception}, formatter: entry_formatter)
      expect(matcher.diff(entry)).to eq({})
    end

    it "shows the formatted filter value in the diff when both comparisons fail" do
      other = RuntimeError.new("different")
      matcher = Lumberjack::LogEntryMatcher.new(message: other, formatter: entry_formatter)
      expect(matcher.diff(entry)).to eq({"message" => {expected: other.inspect, actual: entry.message}})
    end

    it "reports mismatches inside a formatted attribute filter per attribute" do
      other = RuntimeError.new("different")
      other.set_backtrace(exception.backtrace)
      matcher = Lumberjack::LogEntryMatcher.new(attributes: {error: other}, formatter: entry_formatter)
      expect(matcher.diff(entry)).to eq({
        "attributes" => {"error.message" => {expected: "different", actual: "boom"}}
      })
    end

    it "shows the formatted attribute filter value in the diff when both comparisons fail" do
      formatter = Lumberjack::EntryFormatter.build do |config|
        config.format_attributes(Symbol, &:to_s)
      end
      plain_entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Test", nil, nil, {"status" => "active"})
      matcher = Lumberjack::LogEntryMatcher.new(attributes: {status: :inactive}, formatter: formatter)
      expect(matcher.diff(plain_entry)).to eq({
        "attributes" => {"status" => {expected: "inactive", actual: "active"}}
      })
    end

    it "shows the raw filter value in the diff when the formatter does not change it" do
      matcher = Lumberjack::LogEntryMatcher.new(message: "Other message", attributes: {key: "value"}, formatter: entry_formatter)
      diff = matcher.diff(entry)
      expect(diff["message"]).to eq({expected: "Other message", actual: entry.message})
      expect(diff["attributes"]).to eq({"key" => {expected: "value", actual: nil}})
    end
  end

  describe "#closest" do
    let(:user_logged_in) { Lumberjack::LogEntry.new(Time.now, Logger::INFO, "User logged in successfully", nil, nil, nil) }
    let(:database_slow) { Lumberjack::LogEntry.new(Time.now, Logger::WARN, "Database connection slow", nil, nil, nil) }
    let(:failed_auth) { Lumberjack::LogEntry.new(Time.now, Logger::ERROR, "Failed to authenticate user", nil, nil, nil) }
    let(:processing_request) { Lumberjack::LogEntry.new(Time.now, Logger::DEBUG, "Processing request", nil, nil, {"user_id" => 123, "action" => "login"}) }
    let(:service_started) { Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Service started", "TestService", nil, {"service" => "test"}) }
    let(:entries) do
      [
        user_logged_in,
        database_slow,
        failed_auth,
        processing_request,
        service_started
      ]
    end

    it "should return nil when there are no entries" do
      matcher = Lumberjack::LogEntryMatcher.new(severity: :info, message: "test")
      expect(matcher.closest([])).to be_nil
    end

    it "should return the exact match when criteria match perfectly" do
      matcher = Lumberjack::LogEntryMatcher.new(severity: :info, message: "User logged in successfully")
      expect(matcher.closest(entries)).to eq user_logged_in
    end

    it "should handle regex patterns in message matching" do
      matcher = Lumberjack::LogEntryMatcher.new(message: /authenticate/)
      expect(matcher.closest(entries)).to eq failed_auth
    end

    it "should return the closest match based on message similarity" do
      matcher = Lumberjack::LogEntryMatcher.new(severity: :info, message: "User login successful")
      expect(matcher.closest(entries)).to eq user_logged_in
    end

    it "should find matches with the approximate severity when exact severity doesn't match" do
      matcher = Lumberjack::LogEntryMatcher.new(severity: :info, message: "Database connection")
      expect(matcher.closest(entries)).to eq database_slow
    end

    it "should match based on attributes" do
      matcher = Lumberjack::LogEntryMatcher.new(attributes: {user_id: 123})
      expect(matcher.closest(entries)).to eq processing_request
    end

    it "should handle nested attribute matching" do
      nested_entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Nested test", nil, nil, {"user.id" => 456, "user.name" => "John"})
      entries << nested_entry
      matcher = Lumberjack::LogEntryMatcher.new(attributes: {user: {id: 456}})
      expect(matcher.closest(entries)).to eq nested_entry
    end

    it "should match based on progname" do
      matcher = Lumberjack::LogEntryMatcher.new(progname: "TestService")
      expect(matcher.closest(entries)).to eq service_started
    end

    it "should handle string similarity for progname" do
      matcher = Lumberjack::LogEntryMatcher.new(progname: "TestServ")
      expect(matcher.closest(entries)).to eq service_started
    end

    it "should return nil when no entry meets minimum criteria" do
      matcher = Lumberjack::LogEntryMatcher.new(severity: :fatal, message: "Completely different message")
      expect(matcher.closest(entries)).to be_nil
    end

    it "should handle multiple criteria and weight them properly" do
      matcher = Lumberjack::LogEntryMatcher.new(
        severity: :debug,
        message: "Processing",
        attributes: {action: "login"}
      )
      result = matcher.closest(entries)
      expect(result).to eq processing_request
    end

    it "should return the best match when multiple entries partially match" do
      entries = [
        Lumberjack::LogEntry.new(Time.now, Logger::INFO, "User authentication started", nil, nil, nil),
        Lumberjack::LogEntry.new(Time.now, Logger::INFO, "User authentication failed", nil, nil, nil),
        Lumberjack::LogEntry.new(Time.now, Logger::INFO, "User authentication successful", nil, nil, nil)
      ]

      matcher = Lumberjack::LogEntryMatcher.new(message: "authentication success")
      expect(matcher.closest(entries).message).to eq "User authentication successful"
    end
  end
end
