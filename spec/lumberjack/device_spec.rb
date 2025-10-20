# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Device do
  describe ".open_device" do
    it "passes the options to the underlying device" do
      device = Lumberjack::Device.open_device(:test, max_entries: 5)
      expect(device.max_entries).to eq(5)
    end

    it "returns a Null device when given nil" do
      device = Lumberjack::Device.open_device(nil)
      expect(device).to be_a(Lumberjack::Device::Null)
    end

    it "returns the device when given a Lumberjack::Device" do
      original_device = Lumberjack::Device::Test.new
      device = Lumberjack::Device.open_device(original_device)
      expect(device).to equal(original_device)
    end

    it "looks up a device in the registry when given a Symbol" do
      device = Lumberjack::Device.open_device(:test)
      expect(device).to be_a(Lumberjack::Device::Test)
    end

    it "opens a LogFile when given a String path" do
      tmp_file = Tempfile.new("lumberjack_test")
      begin
        device = Lumberjack::Device.open_device(tmp_file.path)
        expect(device).to be_a(Lumberjack::Device::LogFile)
        expect(device.dev.path).to eq(tmp_file.path)
      ensure
        tmp_file.unlink
      end
    end

    it "opens a LogFile when given a Pathname" do
      tmp_file = Tempfile.new("lumberjack_test")
      begin
        path = Pathname.new(tmp_file.path)
        device = Lumberjack::Device.open_device(path)
        expect(device).to be_a(Lumberjack::Device::LogFile)
        expect(device.dev.path).to eq(tmp_file.path)
      ensure
        tmp_file.unlink
      end
    end

    it "opens a LogFile when given a File" do
      tmp_file = Tempfile.new("lumberjack_test")
      file = File.open(tmp_file.path, "a")
      begin
        device = Lumberjack::Device.open_device(file)
        expect(device).to be_a(Lumberjack::Device::LogFile)
        expect(device.dev.path).to eq(tmp_file.path)
      ensure
        file.close
        tmp_file.unlink
      end
    end

    it "opens a Writer when given an IO that is not a File" do
      string_io = StringIO.new
      device = Lumberjack::Device.open_device(string_io)
      expect(device).to be_a(Lumberjack::Device::Writer)
      expect(device.dev).to equal(string_io)
    end

    it "wraps a ContextLogger in a LoggerWrapper" do
      context_logger = Lumberjack::Logger.new(:test)
      device = Lumberjack::Device.open_device(context_logger)
      expect(device).to be_a(Lumberjack::Device::LoggerWrapper)
      expect(device.logger).to equal(context_logger)
    end

    it "wraps a ::Logger in a LoggerWrapper" do
      logger = ::Logger.new(File::NULL)
      device = Lumberjack::Device.open_device(logger)
      expect(device).to be_a(Lumberjack::Device::LoggerWrapper)
      expect(device.logger).to equal(logger)
    end

    it "opens multiple devices when given an Array and can pass shared and device specific options" do
      out_1 = StringIO.new
      out_2 = StringIO.new
      device = Lumberjack::Device.open_device([out_1, [out_2, {attribute_format: "(%s=%s)"}]], template: "{{message}} {{attributes}}")
      expect(device).to be_a(Lumberjack::Device::Multi)
      device_1 = device.devices[0]
      device_2 = device.devices[1]
      expect(device_1).to be_a(Lumberjack::Device::Writer)
      expect(device_2).to be_a(Lumberjack::Device::Writer)

      entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Test", "test", 123, {"foo" => "bar"})
      device.write(entry)
      expect(out_1.string).to eq("Test [foo:bar]#{Lumberjack::LINE_SEPARATOR}")
      expect(out_2.string).to eq("Test (foo=bar)#{Lumberjack::LINE_SEPARATOR}")
    end
  end
end
