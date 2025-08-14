# frozen_string_literal: true

require "spec_helper"

describe Lumberjack::IOCompatibility do
  let(:logger) { TestContextLogger.new }
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
