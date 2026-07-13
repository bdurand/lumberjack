# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Template do
  let(:time_string) { "2011-01-15T14:23:45.123" }
  let(:time) { Time.parse(time_string) }
  let(:entry) { Lumberjack::LogEntry.new(time, Logger::INFO, "line 1#{Lumberjack::LINE_SEPARATOR}line 2#{Lumberjack::LINE_SEPARATOR}line 3", "app", 12345, "unit_of_work_id" => "ABCD", "foo" => "bar") }

  describe ".colorize_entry" do
    it "wraps each line in terminal save/restore sequences" do
      colored = Lumberjack::Template.colorize_entry("line 1#{Lumberjack::LINE_SEPARATOR}line 2", entry)
      expect(colored).to eq("\e7\e[38;5;33mline 1\e8#{Lumberjack::LINE_SEPARATOR}\e7\e[38;5;33mline 2\e8")
    end
  end

  describe "output normalization" do
    it "always ends the output with exactly one line separator and no trailing whitespace" do
      single_line_entry = Lumberjack::LogEntry.new(time, Logger::INFO, "message", "app", 12345, nil)
      template = Lumberjack::Template.new("{{message}} {{progname}} {{attributes}}")
      output = template.call(single_line_entry)
      expect(output).to eq("message app#{Lumberjack::LINE_SEPARATOR}")
    end

    it "normalizes colorized output to end with a line separator" do
      single_line_entry = Lumberjack::LogEntry.new(time, Logger::INFO, "message", "app", 12345, nil)
      template = Lumberjack::Template.new("{{message}}", colorize: true)
      output = template.call(single_line_entry)
      expect(output).to end_with("\e8#{Lumberjack::LINE_SEPARATOR}")
      expect(output.scan(Lumberjack::LINE_SEPARATOR).size).to eq(1)
    end
  end

  describe "timestamp caching" do
    def entry_at(time)
      Lumberjack::LogEntry.new(time, Logger::INFO, "message", "app", 12345, nil)
    end

    it "reuses the formatted timestamp for entries in the same millisecond" do
      template = Lumberjack::Template.new("{{time}} {{message}}")
      time_1 = Time.local(2011, 1, 15, 14, 23, 45, 123_400)
      time_2 = Time.local(2011, 1, 15, 14, 23, 45, 123_900)
      expect(template.call(entry_at(time_1))).to eq("2011-01-15T14:23:45.123 message#{Lumberjack::LINE_SEPARATOR}")
      expect(template.call(entry_at(time_2))).to eq("2011-01-15T14:23:45.123 message#{Lumberjack::LINE_SEPARATOR}")
    end

    it "formats distinct timestamps for entries in different milliseconds" do
      template = Lumberjack::Template.new("{{time}} {{message}}")
      time_1 = Time.local(2011, 1, 15, 14, 23, 45, 123_000)
      time_2 = Time.local(2011, 1, 15, 14, 23, 45, 124_000)
      expect(template.call(entry_at(time_1))).to eq("2011-01-15T14:23:45.123 message#{Lumberjack::LINE_SEPARATOR}")
      expect(template.call(entry_at(time_2))).to eq("2011-01-15T14:23:45.124 message#{Lumberjack::LINE_SEPARATOR}")
    end

    it "does not reuse the cached timestamp for the same instant in a different time zone" do
      template = Lumberjack::Template.new("{{time}} {{message}}")
      utc_time = Time.utc(2011, 1, 15, 14, 23, 45, 123_000)
      local_time = utc_time.getlocal("-05:00")
      expect(template.call(entry_at(utc_time))).to eq("2011-01-15T14:23:45.123 message#{Lumberjack::LINE_SEPARATOR}")
      expect(template.call(entry_at(local_time))).to eq("2011-01-15T09:23:45.123 message#{Lumberjack::LINE_SEPARATOR}")
    end

    it "reuses the formatted timestamp with microsecond precision" do
      template = Lumberjack::Template.new("{{time}} {{message}}", time_format: :microseconds)
      time_1 = Time.local(2011, 1, 15, 14, 23, 45, Rational(123_456_700, 1000))
      time_2 = Time.local(2011, 1, 15, 14, 23, 45, Rational(123_456_900, 1000))
      expect(template.call(entry_at(time_1))).to eq("2011-01-15T14:23:45.123456 message#{Lumberjack::LINE_SEPARATOR}")
      expect(template.call(entry_at(time_2))).to eq("2011-01-15T14:23:45.123456 message#{Lumberjack::LINE_SEPARATOR}")
    end

    it "does not cache timestamps formatted with a custom format" do
      template = Lumberjack::Template.new("{{time}} {{message}}", time_format: "%H:%M:%S.%2N")
      time_1 = Time.local(2011, 1, 15, 14, 23, 45, 123_000)
      time_2 = Time.local(2011, 1, 15, 14, 23, 45, 127_000)
      expect(template.call(entry_at(time_1))).to eq("14:23:45.12 message#{Lumberjack::LINE_SEPARATOR}")
      expect(template.call(entry_at(time_2))).to eq("14:23:45.12 message#{Lumberjack::LINE_SEPARATOR}")
    end

    it "resets the cache when the datetime format is changed" do
      template = Lumberjack::Template.new("{{time}} {{message}}")
      time = Time.local(2011, 1, 15, 14, 23, 45, 123_400)
      expect(template.call(entry_at(time))).to eq("2011-01-15T14:23:45.123 message#{Lumberjack::LINE_SEPARATOR}")
      template.datetime_format = :microseconds
      expect(template.call(entry_at(time))).to eq("2011-01-15T14:23:45.123400 message#{Lumberjack::LINE_SEPARATOR}")
    end
  end

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
