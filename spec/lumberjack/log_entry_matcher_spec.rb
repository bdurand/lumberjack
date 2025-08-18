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
end
