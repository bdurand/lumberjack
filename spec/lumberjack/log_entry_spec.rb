require "spec_helper"

RSpec.describe Lumberjack::LogEntry do
  describe "attributes" do
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
      expect(Lumberjack::LogEntry.new(Time.now, -100, "test", "app", 1500, nil).severity_label).to eq("UNKNOWN")
      expect(Lumberjack::LogEntry.new(Time.now, 1000, "test", "app", 1500, nil).severity_label).to eq("UNKNOWN")
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

  describe "#tags" do
    it "should have tags" do
      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, "foo" => "ABCD")
      expect(entry.tags).to eq("foo" => "ABCD")
    end

    it "should compact tags that are set to empty values" do
      tags = {
        "a" => "A",
        "b" => nil,
        "c" => "",
        "d" => {"e" => "E", "f" => nil},
        "g" => {"h" => "", "i" => []}
      }

      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, tags)
      expect(entry.tags).to eq("a" => "A", "d" => {"e" => "E"})
    end
  end

  describe "#empty?" do
    it "is empty if the log has no message and no tags" do
      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, nil, "app", 1500, nil)
      expect(entry.empty?).to be true

      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "", "app", 1500, {})
      expect(entry.empty?).to be true

      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "message", "app", 1500, nil)
      expect(entry.empty?).to be false

      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, nil, "app", 1500, {tag: "value"})
      expect(entry.empty?).to be false
    end
  end

  describe "#tag" do
    it "returns the tag value for a given name" do
      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, "a" => 1, "b" => 2)
      expect(entry.tag("a")).to eq(1)
      expect(entry.tag("b")).to eq(2)
      expect(entry.tag("non_existent")).to be_nil
    end

    it "returns a hash when a tag is a parent of a dot notation key" do
      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, "foo.bar" => "baz", "foo.far" => "qux")
      expect(entry.tag("foo")).to eq({"bar" => "baz", "far" => "qux"})
      expect(entry.tag("foo.bar")).to eq("baz")
      expect(entry.tag("foo.far")).to eq("qux")
    end
  end

  describe "#nested_tags" do
    it "expands tags into a nested structure" do
      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, "a.b.c" => 1, "a.b.d" => 2)
      expect(entry.nested_tags).to eq({"a" => {"b" => {"c" => 1, "d" => 2}}})
    end

    it "returns an empty hash if there are no tags" do
      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, nil)
      expect(entry.nested_tags).to eq({})
    end
  end
end
