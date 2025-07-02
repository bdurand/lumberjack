require "spec_helper"

RSpec.describe Lumberjack::LogEntry do
  it "should have a time" do
    t = Time.now
    entry = Lumberjack::LogEntry.new(t, Logger::INFO, "test", "app", 1500, "unit_of_work_id" => "ABCD")
    expect(entry.time).to eq(t)
    entry.time = t + 1
    expect(entry.time).to eq(t + 1)
  end

  it "should have a severity" do
    entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, "unit_of_work_id" => "ABCD")
    expect(entry.severity).to eq(Logger::INFO)
    entry.severity = Logger::WARN
    expect(entry.severity).to eq(Logger::WARN)
  end

  it "should convert a severity label to a numeric level" do
    entry = Lumberjack::LogEntry.new(Time.now, "INFO", "test", "app", 1500, "unit_of_work_id" => "ABCD")
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
    entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, "unit_of_work_id" => "ABCD")
    expect(entry.message).to eq("test")
    entry.message = "new message"
    expect(entry.message).to eq("new message")
  end

  it "should have a progname" do
    entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, "unit_of_work_id" => "ABCD")
    expect(entry.progname).to eq("app")
    entry.progname = "prog"
    expect(entry.progname).to eq("prog")
  end

  it "should have a pid" do
    entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, "unit_of_work_id" => "ABCD")
    expect(entry.pid).to eq(1500)
    entry.pid = 150
    expect(entry.pid).to eq(150)
  end

  it "should have tags" do
    entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, "unit_of_work_id" => "ABCD")
    expect(entry.tags).to eq("unit_of_work_id" => "ABCD")
  end

  it "should have a unit_of_work_id for backward compatibility with the 1.0 API" do
    entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 1500, "ABCD")
    expect(entry.unit_of_work_id).to eq("ABCD")
    entry.unit_of_work_id = "1234"
    expect(entry.unit_of_work_id).to eq("1234")
  end

  it "should be converted to a string" do
    t = Time.parse("2011-01-29T12:15:32.001")
    entry = Lumberjack::LogEntry.new(t, Logger::INFO, "test", "app", 1500, "unit_of_work_id" => "ABCD")
    expect(entry.to_s).to eq('[2011-01-29T12:15:32.001 INFO app(1500) unit_of_work_id:"ABCD"] test')
  end
end
