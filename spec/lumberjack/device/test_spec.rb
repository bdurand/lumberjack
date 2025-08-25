# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Device::Test do
  let(:device) { Lumberjack::Device::Test.new }

  describe "#max_entries" do
    it "is 1000 by default" do
      expect(device.max_entries).to eq(1000)
    end
  end

  describe "#write" do
    it "captures log entries" do
      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Test message", nil, nil, nil)
      device.write(entry)
      expect(device.entries).to eq([entry])
    end

    it "only keeps the last n entries" do
      device.max_entries = 3
      entry_1 = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Entry 1", nil, nil, nil)
      entry_2 = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Entry 2", nil, nil, nil)
      entry_3 = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Entry 3", nil, nil, nil)
      entry_4 = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Entry 4", nil, nil, nil)
      device.write(entry_1)
      device.write(entry_2)
      device.write(entry_3)
      device.write(entry_4)
      expect(device.entries).to eq([entry_2, entry_3, entry_4])
    end
  end

  describe "#flush" do
    it "clears all captured log entries" do
      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Test message", nil, nil, nil)
      device.write(entry)
      expect(device.entries).to eq([entry])
      device.flush
      expect(device.entries).to be_empty
    end
  end

  describe "#entries" do
    it "returns all captured log entries" do
      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Test message", nil, nil, nil)
      device.write(entry)
      expect(device.entries).to eq([entry])
    end
  end

  describe "#include?" do
    it "is true if the entry matches one in the buffer" do
      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Test message", nil, nil, nil)
      device.write(entry)
      expect(device.include?(message: "Test message")).to be true
      expect(device.include?(message: "Different message")).to be false
    end
  end

  describe "#match" do
    it "returns the first match" do
      entry_1 = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Message 1", nil, nil, nil)
      entry_2 = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Message 2", nil, nil, nil)
      entry_3 = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Message 3", nil, nil, nil)
      device.write(entry_1)
      device.write(entry_2)
      device.write(entry_3)
      expect(device.match(message: "Message 2")).to eq(entry_2)
      expect(device.match(message: "Different message")).to be_nil
    end

    it "can match by severity" do
      entry_1 = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Message 1", nil, nil, nil)
      entry_2 = Lumberjack::LogEntry.new(Time.now, Logger::WARN, "Message 2", nil, nil, nil)
      device.write(entry_1)
      device.write(entry_2)
      expect(device.match(severity: Logger::INFO)).to eq(entry_1)
      expect(device.match(severity: Logger::WARN)).to eq(entry_2)
      expect(device.match(severity: Logger::ERROR)).to be_nil
    end

    it "can match by progname" do
      entry_1 = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Message 1", "progname1", nil, nil)
      entry_2 = Lumberjack::LogEntry.new(Time.now, Logger::WARN, "Message 2", "progname2", nil, nil)
      device.write(entry_1)
      device.write(entry_2)
      expect(device.match(progname: "progname1")).to eq(entry_1)
      expect(device.match(progname: "progname2")).to eq(entry_2)
      expect(device.match(progname: "different_progname")).to be_nil
    end

    it "can match by attributes" do
      entry_1 = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Message 1", "progname1", nil, {"foo" => "bar"})
      entry_2 = Lumberjack::LogEntry.new(Time.now, Logger::WARN, "Message 2", "progname2", nil, {"foo" => "baz"})
      device.write(entry_1)
      device.write(entry_2)
      expect(device.match(attributes: {foo: "bar"})).to eq(entry_1)
      expect(device.match(attributes: {foo: "baz"})).to eq(entry_2)
      expect(device.match(attributes: {foo: "qux"})).to be_nil
    end
  end

  describe "#dev" do
    it "returns self underlying stream" do
      device = Lumberjack::Device::Test.new
      expect(device.dev).to eq(device)
    end
  end
end
