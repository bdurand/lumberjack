# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Device::LoggerWrapper do
  it "wraps another Lumberjack logger as a device" do
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

  it "wraps a forked logger as a device" do
    logger = Lumberjack::Logger.new(:test)
    forked_logger = logger.fork
    outer_logger = Lumberjack::Logger.new(forked_logger, progname: "MyApp")
    outer_logger.info("Test log message", foo: "bar")
    expect(logger.device).to(
      include(severity: :info, message: "Test log message", progname: "MyApp", attributes: {"foo" => "bar"})
    )
  end

  it "wraps a standard Ruby Logger as a device" do
    stream = StringIO.new
    ruby_logger = ::Logger.new(stream)
    outer_logger = Lumberjack::Logger.new(Lumberjack::Device::LoggerWrapper.new(ruby_logger), progname: "MyApp")
    outer_logger.warn("No attributes")
    outer_logger.info("With attributes", foo: "bar", baz: [1, 2, 3])
    log_output = stream.string
    expect(log_output).to include("WARN -- MyApp: No attributes")
    expect(log_output).to include("INFO -- MyApp: With attributes [foo=bar] [baz=1,2,3]")
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
