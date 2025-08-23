# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::DeviceRegistry do
  it "has :null and :test registered by default" do
    expect(Lumberjack::DeviceRegistry.registered_devices).to eq({
      null: Lumberjack::Device::Null,
      test: Lumberjack::Device::Test
    })
  end

  it "can add new devices to the registry" do
    Lumberjack::DeviceRegistry.add(:foobar, Object)
    expect(Lumberjack::DeviceRegistry.device_class(:foobar)).to eq Object
    expect(Lumberjack::DeviceRegistry.device_class(:other)).to be_nil
  ensure
    Lumberjack::DeviceRegistry.remove(:foobar)
  end

  it "can instantiate a device by name and options" do
    device = Lumberjack::DeviceRegistry.new_device(:test, max_entries: 15)
    expect(device).to be_a(Lumberjack::Device::Test)
    expect(device.max_entries).to eq 15
  end
end
