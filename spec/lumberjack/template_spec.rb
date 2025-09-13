# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Template do
  let(:time_string) { "2011-01-15T14:23:45.123" }
  let(:time) { Time.parse(time_string) }
  let(:entry) { Lumberjack::LogEntry.new(time, Logger::INFO, "line 1#{Lumberjack::LINE_SEPARATOR}line 2#{Lumberjack::LINE_SEPARATOR}line 3", "app", 12345, "unit_of_work_id" => "ABCD", "foo" => "bar") }

  describe "format" do
    it "has a default format" do
      template = Lumberjack::Template.new
      expect(template.call(entry)).to eq("[2011-01-15T14:23:45.123 INFO  app(12345)] line 1 [unit_of_work_id:ABCD] [foo:bar]#{Lumberjack::LINE_SEPARATOR}> line 2#{Lumberjack::LINE_SEPARATOR}> line 3#{Lumberjack::LINE_SEPARATOR}")
    end

    it "should format a log entry with a template string" do
      template = Lumberjack::Template.new("{{message}} - {{severity}}, {{time}}, {{progname}}@{{pid}} ({{unit_of_work_id}}) {{attributes}}")
      expect(template.call(entry)).to eq("line 1 - INFO, 2011-01-15T14:23:45.123, app@12345 (ABCD) [foo:bar]#{Lumberjack::LINE_SEPARATOR}> line 2#{Lumberjack::LINE_SEPARATOR}> line 3#{Lumberjack::LINE_SEPARATOR}")
    end

    it "should be able to specify a template for additional lines in a message" do
      template = Lumberjack::Template.new("{{message}} ({{time}})", additional_lines: " // {{message}}")
      expect(template.call(entry)).to eq("line 1 (2011-01-15T14:23:45.123) // line 2 // line 3#{Lumberjack::LINE_SEPARATOR}")
    end

    it "does not blow up if there is a % in the template" do
      template = Lumberjack::Template.new("%s {{message}}")
      expect(template.call(entry)).to eq("%s line 1#{Lumberjack::LINE_SEPARATOR}> line 2#{Lumberjack::LINE_SEPARATOR}> line 3#{Lumberjack::LINE_SEPARATOR}")
    end

    it "can pad the severity labels" do
      template = Lumberjack::Template.new("{{severity(padded)}}-{{message}}")
      expect(template.call(entry)).to start_with("INFO -line 1")
    end

    it "can use a single character for the severity" do
      template = Lumberjack::Template.new("{{severity(char)}}-{{message}}")
      expect(template.call(entry)).to start_with("I-line 1")
    end

    it "can use an emoji for the severity" do
      template = Lumberjack::Template.new("{{severity(emoji)}}-{{message}}")
      expect(template.call(entry)).to start_with("🔵-line 1")
    end

    it "can use the level for the severity" do
      template = Lumberjack::Template.new("{{severity(level)}}-{{message}}")
      expect(template.call(entry)).to start_with("1-line 1")
    end
  end

  describe "timestamp format" do
    it "should be able to specify the time format for log entries as microseconds" do
      template = Lumberjack::Template.new("{{message}} ({{time}})", time_format: :microseconds)
      expect(template.call(entry)).to eq("line 1 (2011-01-15T14:23:45.123000)#{Lumberjack::LINE_SEPARATOR}> line 2#{Lumberjack::LINE_SEPARATOR}> line 3#{Lumberjack::LINE_SEPARATOR}")
    end

    it "should be able to specify the time format for log entries as milliseconds" do
      template = Lumberjack::Template.new("{{message}} ({{time}})", time_format: :milliseconds)
      expect(template.call(entry)).to eq("line 1 (2011-01-15T14:23:45.123)#{Lumberjack::LINE_SEPARATOR}> line 2#{Lumberjack::LINE_SEPARATOR}> line 3#{Lumberjack::LINE_SEPARATOR}")
    end

    it "should be able to specify the time format for log entries with a custom format" do
      template = Lumberjack::Template.new("{{message}} ({{time}})", time_format: "%m/%d/%Y, %I:%M:%S %p")
      expect(template.call(entry)).to eq("line 1 (01/15/2011, 02:23:45 PM)#{Lumberjack::LINE_SEPARATOR}> line 2#{Lumberjack::LINE_SEPARATOR}> line 3#{Lumberjack::LINE_SEPARATOR}")
    end
  end

  describe "attributes" do
    it "should format named attributes in the template and not in the {{attributes}} placement" do
      template = Lumberjack::Template.new("{{message}} - {{foo}} - {{attributes}}")
      entry = Lumberjack::LogEntry.new(time, Logger::INFO, "here", "app", 12345, "foo" => "bar", "tag" => "a")
      expect(template.call(entry)).to eq("here - bar - [tag:a]#{Lumberjack::LINE_SEPARATOR}")
    end

    it "should put nothing in place of missing named attributes" do
      template = Lumberjack::Template.new("{{message}} - {{foo}} - {{attributes}}")
      entry = Lumberjack::LogEntry.new(time, Logger::INFO, "here", "app", 12345, "tag" => "a")
      expect(template.call(entry)).to eq("here -  - [tag:a]#{Lumberjack::LINE_SEPARATOR}")
    end

    it "should remove line separators in attributes" do
      template = Lumberjack::Template.new("{{message}} - {{foo}} - {{attributes}}")
      entry = Lumberjack::LogEntry.new(time, Logger::INFO, "here", "app", 12345, "tag" => "a#{Lumberjack::LINE_SEPARATOR}b")
      expect(template.call(entry)).to eq("here -  - [tag:a b]#{Lumberjack::LINE_SEPARATOR}")
    end

    it "should handle attributes with special characters by surrounding with brackets" do
      template = Lumberjack::Template.new("{{message}} - {{ foo.bar }} - {{@baz!}} - {{ attributes}}")
      entry = Lumberjack::LogEntry.new(time, Logger::INFO, "here", "app", 12345, "foo.bar" => "test", "@baz!" => 1, "tag" => "a")
      expect(template.call(entry)).to eq("here - test - 1 - [tag:a]#{Lumberjack::LINE_SEPARATOR}")
    end

    it "can customize the attribute format" do
      template = Lumberjack::Template.new("{{message}} - {{foo}} - {{attributes}}", attribute_format: "(%s=%s)")
      entry = Lumberjack::LogEntry.new(time, Logger::INFO, "here", "app", 12345, "foo" => "bar", "tag" => "a")
      expect(template.call(entry)).to eq("here - bar - (tag=a)#{Lumberjack::LINE_SEPARATOR}")
    end
  end

  describe "v1 template format", deprecation_mode: :silent do
    it "uses :name as placeholders in place of {{name}} and tags instead of attributes" do
      template = Lumberjack::Template.new(":time :severity :progname, :message: - :foo - :tags")
      entry = Lumberjack::LogEntry.new(time, Logger::INFO, "here", "app", 12345, "foo" => "bar", "tag" => "a")
      expect(template.call(entry)).to eq("2011-01-15T14:23:45.123 INFO app, here: - bar - [tag:a]#{Lumberjack::LINE_SEPARATOR}")
    end
  end
end
