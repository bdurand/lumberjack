# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::LogEntry do
  describe "entry values" do
    it "should have a time" do
      t = Time.now
      entry = Lumberjack::LogEntry.new(t, Logger::INFO, "test", "app", 1500, "foo" => "ABCD")
      expect(entry.time).to eq(t)
      entry.time = t + 1
      expect(entry.time).to eq(t + 1)
    end

    it "should have a severity" do
      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, "foo" => "ABCD")
      expect(entry.severity).to eq(Logger::INFO)
      entry.severity = Logger::WARN
      expect(entry.severity).to eq(Logger::WARN)
    end

    it "should convert a severity label to a numeric level" do
      entry = Lumberjack::LogEntry.new(Time.now, "INFO", "test", "app", 1500, "foo" => "ABCD")
      expect(entry.severity).to eq(Logger::INFO)
    end

    it "should get the severity as a string" do
      expect(Lumberjack::LogEntry.new(Time.now, Logger::DEBUG, "test", "app", 1500, nil).severity_label).to eq("DEBUG")
      expect(Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, nil).severity_label).to eq("INFO")
      expect(Lumberjack::LogEntry.new(Time.now, Logger::WARN, "test", "app", 1500, nil).severity_label).to eq("WARN")
      expect(Lumberjack::LogEntry.new(Time.now, Logger::ERROR, "test", "app", 1500, nil).severity_label).to eq("ERROR")
      expect(Lumberjack::LogEntry.new(Time.now, Logger::FATAL, "test", "app", 1500, nil).severity_label).to eq("FATAL")
      expect(Lumberjack::LogEntry.new(Time.now, -100, "test", "app", 1500, nil).severity_label).to eq("ANY")
      expect(Lumberjack::LogEntry.new(Time.now, 1000, "test", "app", 1500, nil).severity_label).to eq("ANY")
    end

    it "should have a message" do
      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, "foo" => "ABCD")
      expect(entry.message).to eq("test")
      entry.message = "new message"
      expect(entry.message).to eq("new message")
    end

    it "should have a progname" do
      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, "foo" => "ABCD")
      expect(entry.progname).to eq("app")
      entry.progname = "prog"
      expect(entry.progname).to eq("prog")
    end

    it "should have a pid" do
      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, "foo" => "ABCD")
      expect(entry.pid).to eq(1500)
      entry.pid = 150
      expect(entry.pid).to eq(150)
    end
  end

  describe "#severity_data" do
    it "returns the severity data object" do
      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, "foo" => "ABCD")
      expect(entry.severity_data).to eq(Lumberjack::Severity.data(Logger::INFO))
    end
  end

  describe "#attributes" do
    it "should have attributes" do
      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, "foo" => "ABCD")
      expect(entry.attributes).to eq("foo" => "ABCD")
    end

    it "should compact attributes that are set to empty values" do
      attributes = {
        "a" => "A",
        "b" => nil,
        "c" => "",
        "d" => {"e" => "E", "f" => nil},
        "g" => {"h" => "", "i" => []}
      }

      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, attributes)
      expect(entry.attributes).to eq("a" => "A", "d" => {"e" => "E"})
    end
  end

  describe "#empty?" do
    it "is empty if the log has no message and no attributes" do
      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, nil, "app", 1500, nil)
      expect(entry.empty?).to be true

      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "", "app", 1500, {})
      expect(entry.empty?).to be true

      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "message", "app", 1500, nil)
      expect(entry.empty?).to be false

      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, nil, "app", 1500, {attribute: "value"})
      expect(entry.empty?).to be false
    end
  end

  describe "#[]]" do
    it "returns the attribute value for a given name" do
      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, "a" => 1, "b" => 2)
      expect(entry["a"]).to eq(1)
      expect(entry["b"]).to eq(2)
      expect(entry["non_existent"]).to be_nil
    end

    it "returns a hash when a attribute is a parent of a dot notation key" do
      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, "foo.bar" => "baz", "foo.far" => "qux")
      expect(entry["foo"]).to eq({"bar" => "baz", "far" => "qux"})
      expect(entry["foo.bar"]).to eq("baz")
      expect(entry["foo.far"]).to eq("qux")
    end

    it "return nil if there are no tags" do
      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, nil)
      expect(entry["a"]).to be_nil
    end
  end

  describe "#nested_attributes" do
    it "expands attributes into a nested structure" do
      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, "a.b.c" => 1, "a.b.d" => 2)
      expect(entry.nested_attributes).to eq({"a" => {"b" => {"c" => 1, "d" => 2}}})
    end

    it "returns an empty hash if there are no attributes" do
      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, nil)
      expect(entry.nested_attributes).to eq({})
    end
  end

  describe "==" do
    let(:entry) { Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, "foo" => "bar") }
    it "is equal to a log entry with the same attributes" do
      other_entry = Lumberjack::LogEntry.new(entry.time, entry.severity, entry.message, entry.progname, entry.pid, entry.attributes)
      expect(entry).to eq(other_entry)
    end

    it "is not equal to another class type" do
      expect(entry).not_to eq("not a log entry")
    end

    it "is not equal to an entry with a different time" do
      other_entry = Lumberjack::LogEntry.new(entry.time + 1, entry.severity, entry.message, entry.progname, entry.pid, entry.attributes)
      expect(entry).not_to eq(other_entry)
    end

    it "is not equal to an entry with a different severity" do
      other_entry = Lumberjack::LogEntry.new(entry.time, entry.severity + 1, entry.message, entry.progname, entry.pid, entry.attributes)
      expect(entry).not_to eq(other_entry)
    end

    it "is not equal to an entry with a different message" do
      other_entry = Lumberjack::LogEntry.new(entry.time, entry.severity, entry.message + " altered", entry.progname, entry.pid, entry.attributes)
      expect(entry).not_to eq(other_entry)
    end

    it "is not equal to an entry with a different progname" do
      other_entry = Lumberjack::LogEntry.new(entry.time, entry.severity, entry.message, entry.progname + " altered", entry.pid, entry.attributes)
      expect(entry).not_to eq(other_entry)
    end

    it "is not equal to an entry with a different pid" do
      other_entry = Lumberjack::LogEntry.new(entry.time, entry.severity, entry.message, entry.progname, entry.pid + 1, entry.attributes)
      expect(entry).not_to eq(other_entry)
    end

    it "is not equal to an entry with different attributes" do
      other_entry = Lumberjack::LogEntry.new(entry.time, entry.severity, entry.message, entry.progname, entry.pid, {"foo" => "baz"})
      expect(entry).not_to eq(other_entry)
    end
  end

  describe "#as_json" do
    it "returns a hash representation of the log entry" do
      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, "foo.bar" => "baz")
      expect(entry.as_json).to eq({
        "time" => entry.time,
        "severity" => "INFO",
        "message" => entry.message,
        "progname" => entry.progname,
        "pid" => entry.pid,
        "attributes" => {"foo" => {"bar" => "baz"}}
      })
    end
  end
end
