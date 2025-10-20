# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Device::Null do
  it "is registered as :null" do
    expect(Lumberjack::DeviceRegistry.device_class(:null)).to eq(Lumberjack::Device::Null)
  end

  it "should not generate any output" do
    device = Lumberjack::Device::Null.new
    device.write(Lumberjack::LogEntry.new(Time.now, 1, "New log entry", nil, Process.pid, nil))
    device.flush
    device.close
  end
end
