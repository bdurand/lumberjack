# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::LogEntryMatcher do
  describe "#match?" do
    let(:entry) { Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Test message", "AppName", Process.pid, tags) }
    let(:tags) { {} }

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

    describe "tags filter" do
      it "matches if the tag is equal" do
        tags["key"] = "value"
        matcher = Lumberjack::LogEntryMatcher.new(tags: {key: "value"})
        expect(matcher.match?(entry)).to be true
      end

      it "does not match if the tag is not equal" do
        tags["key"] = "value"
        matcher = Lumberjack::LogEntryMatcher.new(tags: {key: "different"})
        expect(matcher.match?(entry)).to be false
      end

      it "matches if the tag matches a pattern" do
        tags["key"] = "value"
        matcher = Lumberjack::LogEntryMatcher.new(tags: {key: /val/})
        expect(matcher.match?(entry)).to be true
      end

      it "does not match if the tag does not match the pattern" do
        tags["key"] = "value"
        matcher = Lumberjack::LogEntryMatcher.new(tags: {key: /different/})
        expect(matcher.match?(entry)).to be false
      end

      it "matches if the tag matches the class" do
        tags["key"] = 14
        matcher = Lumberjack::LogEntryMatcher.new(tags: {key: Integer})
        expect(matcher.match?(entry)).to be true
      end

      it "does not match if the tag does not match the class" do
        tags["key"] = 14
        matcher = Lumberjack::LogEntryMatcher.new(tags: {key: String})
        expect(matcher.match?(entry)).to be false
      end

      it "does not match if the tag does not exist" do
        tags["key"] = "value"
        matcher = Lumberjack::LogEntryMatcher.new(tags: {other_key: "nonexistent"})
        expect(matcher.match?(entry)).to be false
      end

      it "matches if all tags match" do
        tags["key_1"] = "value 1"
        tags["key_2"] = "value 2"
        matcher = Lumberjack::LogEntryMatcher.new(tags: {key_1: "value 1", key_2: "value 2"})
        expect(matcher.match?(entry)).to be true
      end

      it "does not match if any values do not match" do
        tags["key_1"] = "value 1"
        tags["key_2"] = "value 2"
        matcher = Lumberjack::LogEntryMatcher.new(tags: {key_1: "value 1", key_2: "different"})
        expect(matcher.match?(entry)).to be false
      end

      it "matches a nil only if the tag does not exist" do
        tags["key"] = "value"
        expect(Lumberjack::LogEntryMatcher.new(tags: {key: nil}).match?(entry)).to be false
        expect(Lumberjack::LogEntryMatcher.new(tags: {other_key: nil}).match?(entry)).to be true
      end

      it "matches an empty array only if the tag does not exist" do
        tags["key"] = "value"
        expect(Lumberjack::LogEntryMatcher.new(tags: {key: []}).match?(entry)).to be false
        expect(Lumberjack::LogEntryMatcher.new(tags: {other_key: []}).match?(entry)).to be true
      end

      it "matches dot notation on tag filters" do
        tags["foo.bar.baz"] = "boo"
        expect(Lumberjack::LogEntryMatcher.new(tags: {"foo.bar" => {"baz" => "boo"}}).match?(entry)).to be true
        expect(Lumberjack::LogEntryMatcher.new(tags: {"foo.bar" => {"baz" => "bip"}}).match?(entry)).to be false
        expect(Lumberjack::LogEntryMatcher.new(tags: {"foo.bar" => Hash}).match?(entry)).to be true
        expect(Lumberjack::LogEntryMatcher.new(tags: {"foo.bar" => String}).match?(entry)).to be false
      end

      it "matches nested tag filters" do
        tags["foo.bar.baz"] = "boo"
        tags["foo.bar.bip"] = "bop"
        expect(Lumberjack::LogEntryMatcher.new(tags: {foo: {bar: {baz: "boo"}}}).match?(entry)).to be true
        expect(Lumberjack::LogEntryMatcher.new(tags: {foo: {bar: {baz: "boo", bip: /b/}}}).match?(entry)).to be true
        expect(Lumberjack::LogEntryMatcher.new(tags: {foo: {bar: {baz: "boo", bip: /c/}}}).match?(entry)).to be false
        expect(Lumberjack::LogEntryMatcher.new(tags: {foo: {"bar.baz": "boo"}}).match?(entry)).to be true
      end

      it "should match arrays of hashes" do
        tags["foo"] = [{bar: "baz"}, {bip: "bop"}]
        expect(Lumberjack::LogEntryMatcher.new(tags: {foo: [{bar: "baz"}, {bip: "bop"}]}).match?(entry)).to be true
        expect(Lumberjack::LogEntryMatcher.new(tags: {foo: [{bar: "baz"}]}).match?(entry)).to be false
      end

      it "does not match an entry with no tags" do
        entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Test message", nil, nil, nil)
        matcher = Lumberjack::LogEntryMatcher.new(tags: {key: "value"})
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
