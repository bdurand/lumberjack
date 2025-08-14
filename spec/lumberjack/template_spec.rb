# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Template do
  let(:time_string) { "2011-01-15T14:23:45.123" }
  let(:time) { Time.parse(time_string) }
  let(:entry) { Lumberjack::LogEntry.new(time, Logger::INFO, "line 1#{Lumberjack::LINE_SEPARATOR}line 2#{Lumberjack::LINE_SEPARATOR}line 3", "app", 12345, "unit_of_work_id" => "ABCD", "foo" => "bar") }

  describe "format" do
    it "should format a log entry with a template string" do
      template = Lumberjack::Template.new(":message - :severity, :time, :progname@:pid (:unit_of_work_id) :tags")
      expect(template.call(entry)).to eq("line 1 - INFO, 2011-01-15T14:23:45.123, app@12345 (ABCD) [foo:bar]#{Lumberjack::LINE_SEPARATOR}line 2#{Lumberjack::LINE_SEPARATOR}line 3")
    end

    it "should be able to specify a template for additional lines in a message" do
      template = Lumberjack::Template.new(":message (:time)", additional_lines: " // :message")
      expect(template.call(entry)).to eq("line 1 (2011-01-15T14:23:45.123) // line 2 // line 3")
    end
  end

  describe "timestamp format" do
    it "should be able to specify the time format for log entries as microseconds" do
      template = Lumberjack::Template.new(":message (:time)", time_format: :microseconds)
      expect(template.call(entry)).to eq("line 1 (2011-01-15T14:23:45.123000)#{Lumberjack::LINE_SEPARATOR}line 2#{Lumberjack::LINE_SEPARATOR}line 3")
    end

    it "should be able to specify the time format for log entries as milliseconds" do
      template = Lumberjack::Template.new(":message (:time)", time_format: :milliseconds)
      expect(template.call(entry)).to eq("line 1 (2011-01-15T14:23:45.123)#{Lumberjack::LINE_SEPARATOR}line 2#{Lumberjack::LINE_SEPARATOR}line 3")
    end

    it "should be able to specify the time format for log entries with a custom format" do
      template = Lumberjack::Template.new(":message (:time)", time_format: "%m/%d/%Y, %I:%M:%S %p")
      expect(template.call(entry)).to eq("line 1 (01/15/2011, 02:23:45 PM)#{Lumberjack::LINE_SEPARATOR}line 2#{Lumberjack::LINE_SEPARATOR}line 3")
    end
  end

  describe "tags" do
    it "should format named tags in the template and not in the :tags placement" do
      template = Lumberjack::Template.new(":message - :foo - :tags")
      entry = Lumberjack::LogEntry.new(time, Logger::INFO, "here", "app", 12345, "foo" => "bar", "tag" => "a")
      expect(template.call(entry)).to eq("here - bar - [tag:a]")
    end

    it "should put nothing in place of missing named tags" do
      template = Lumberjack::Template.new(":message - :foo - :tags")
      entry = Lumberjack::LogEntry.new(time, Logger::INFO, "here", "app", 12345, "tag" => "a")
      expect(template.call(entry)).to eq("here -  - [tag:a]")
    end

    it "should remove line separators in tags" do
      template = Lumberjack::Template.new(":message - :foo - :tags")
      entry = Lumberjack::LogEntry.new(time, Logger::INFO, "here", "app", 12345, "tag" => "a#{Lumberjack::LINE_SEPARATOR}b")
      expect(template.call(entry)).to eq("here -  - [tag:a b]")
    end

    it "should handle tags with special characters by surrounding with brackets" do
      template = Lumberjack::Template.new(":message - :{foo.bar} - :{@baz!} - :tags")
      entry = Lumberjack::LogEntry.new(time, Logger::INFO, "here", "app", 12345, "foo.bar" => "test", "@baz!" => 1, "tag" => "a")
      expect(template.call(entry)).to eq("here - test - 1 - [tag:a]")
    end
  end
end
