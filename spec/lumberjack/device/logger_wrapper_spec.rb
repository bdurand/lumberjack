# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Device::LoggerWrapper do
  it "wraps another logger as a device" do
    logger = Lumberjack::Logger.new(:test)
    outer_logger = Lumberjack::Logger.new(Lumberjack::Device::LoggerWrapper.new(logger), progname: "MyApp")
    outer_logger.info("Test log message", foo: "bar")
    expect(logger.device).to(
      include(severity: :info, message: "Test log message", progname: "MyApp", attributes: {"foo" => "bar"})
    )
  end

  it "automatically wraps a logger set as the device" do
    logger = Lumberjack::Logger.new(:test)
    outer_logger = Lumberjack::Logger.new(logger, progname: "MyApp")
    outer_logger.info("Test log message", foo: "bar")
    expect(logger.device).to(
      include(severity: :info, message: "Test log message", progname: "MyApp", attributes: {"foo" => "bar"})
    )
  end

  describe "#dev" do
    it "returns the logger deviceunderlying stream" do
      stream = StringIO.new
      logger = Lumberjack::Logger.new(stream)
      device = Lumberjack::Device::LoggerWrapper.new(logger)
      expect(device.dev).to eq(stream)
    end
  end
end
