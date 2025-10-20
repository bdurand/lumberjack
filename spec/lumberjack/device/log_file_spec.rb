# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Device::LogFile do
  let(:out) { StringIO.new }

  it "wraps a ::Logger::LogDevice" do
    device = Lumberjack::Device::LogFile.new(out, template: "{{severity}} {{message}}")
    expect(device.class).to eq(Lumberjack::Device::LogFile)
    device.write(Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Test message", nil, Process.pid, nil))
    expect(out.string.chomp).to eq("INFO Test message")
  end

  it "passes supported device options through to the underlying device" do
    expect(Logger::LogDevice).to receive(:new).with(out, shift_age: 10).and_call_original
    Lumberjack::Device::LogFile.new(out, template: "{{severity}} {{message}}", shift_age: 10)
  end

  it "exposes the file path for the underlying stream" do
    file = Tempfile.new("lumberjack_test")
    file.close
    begin
      device = Lumberjack::Device::LogFile.new(file)
      expect(device.path).to eq(file.path)
    ensure
      file.unlink
    end
  end

  describe "#dev" do
    it "returns the underlying stream" do
      stream = StringIO.new
      device = Lumberjack::Device::LogFile.new(stream)
      expect(device.dev).to eq(stream)
    end
  end

  describe "#reopen" do
    it "calls reopen on the underlying stream with the correct parameters" do
      file = Tempfile.new("lumberjack_test")
      file.close
      begin
        device = Lumberjack::Device::LogFile.new(file.path)
        expect_any_instance_of(::Logger::LogDevice).to receive(:reopen).with(nil).and_call_original
        device.reopen
      ensure
        file.unlink
      end
    end
  end
end
