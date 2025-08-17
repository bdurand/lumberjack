# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::IOCompatibility do
  let(:logger) { TestContextLogger.new(Lumberjack::Context.new) }

  it "can write to the log" do
    logger.write("Hello, world")
    expect(logger.entries).to eq([
      {
        message: "Hello, world",
        severity: Logger::UNKNOWN,
        progname: nil,
        tags: nil
      }
    ])
  end

  it "writes to the log using the default severity" do
    logger.default_severity = Logger::INFO
    logger.write("Hello, world")
    expect(logger.entries).to eq([
      {
        message: "Hello, world",
        severity: Logger::INFO,
        progname: nil,
        tags: nil
      }
    ])
  end

  it "can puts to the log" do
    logger.puts("Hello", "world")
    expect(logger.entries).to eq([
      {
        message: "Hello",
        severity: Logger::UNKNOWN,
        progname: nil,
        tags: nil
      },
      {
        message: "world",
        severity: Logger::UNKNOWN,
        progname: nil,
        tags: nil
      }
    ])
  end

  it "can print objects to the log" do
    logger.print("Hello", "world")
    expect(logger.entries).to eq([
      {
        message: "Hello",
        severity: Logger::UNKNOWN,
        progname: nil,
        tags: nil
      },
      {
        message: "world",
        severity: Logger::UNKNOWN,
        progname: nil,
        tags: nil
      }
    ])
  end

  it "can printf to the log" do
    logger.printf("Hello %s", "world")
    expect(logger.entries).to eq([
      {
        message: "Hello world",
        severity: Logger::UNKNOWN,
        progname: nil,
        tags: nil
      }
    ])
  end

  it "responds to flush" do
    expect { logger.flush }.to_not raise_error
  end

  it "responds to close" do
    expect { logger.close }.to_not raise_error
  end

  it "responds to closed?" do
    expect(logger.closed?).to be false
  end
end
