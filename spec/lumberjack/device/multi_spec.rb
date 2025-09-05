# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Device::Multi do
  let(:output_1) { StringIO.new }
  let(:output_2) { StringIO.new }
  let(:device_1) { Lumberjack::Device::Writer.new(output_1, template: "{{message}}") }
  let(:device_2) { Lumberjack::Device::Writer.new(output_2, template: "{{severity}} - {{message}}") }
  let(:device) { Lumberjack::Device::Multi.new(device_1, device_2) }

  let(:entry) { Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test", "app", 100, {}) }

  it "should write an entry to each device" do
    device.write(entry)
    expect(output_1.string.chomp).to eq "test"
    expect(output_2.string.chomp).to eq "INFO - test"
  end

  it "should flush each device" do
    expect(device_1).to receive(:flush).and_call_original
    expect(device_2).to receive(:flush).and_call_original
    device.flush
  end

  it "should close each device" do
    expect(device_1).to receive(:close).and_call_original
    expect(device_2).to receive(:close).and_call_original
    device.close
  end

  it "should reopen each device" do
    expect(device_1).to receive(:reopen).with(nil).and_call_original
    expect(device_2).to receive(:reopen).with(nil).and_call_original
    device.reopen
  end

  it "should set the dateformat on each device" do
    device.datetime_format = "%Y-%m-%d"
    expect(device.datetime_format).to eq "%Y-%m-%d"
    expect(device_1.datetime_format).to eq "%Y-%m-%d"
    expect(device_2.datetime_format).to eq "%Y-%m-%d"
  end
end
