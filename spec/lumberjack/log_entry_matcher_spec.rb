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
