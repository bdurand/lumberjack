# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Device::File do
  let(:out) { StringIO.new }

  it "wraps a ::Logger::LogDevice" do
    device = Lumberjack::Device::File.new(out, template: ":severity :message")
    expect(device.class).to eq(Lumberjack::Device::File)
    device.write(Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Test message", nil, Process.pid, nil))
    expect(out.string.chomp).to eq("INFO Test message")
  end

  it "passes supported device options through to the underlying device" do
    expect(Logger::LogDevice).to receive(:new).with(out, shift_age: 10).and_call_original
    Lumberjack::Device::File.new(out, template: ":severity :message", shift_age: 10)
  end
end
