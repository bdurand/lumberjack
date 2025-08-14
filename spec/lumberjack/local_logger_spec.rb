# frozen_string_literal: true

require "spec_helper"

describe Lumberjack::LocalLogger do
  let(:logger) { TestContextLogger.new(Lumberjack::Context.new) }

  it "logs to the parent logger" do
    local_logger = Lumberjack::LocalLogger.new(logger)

    local_logger.info("Test message")

    expect(logger.entries.first).to eq({
      severity: Logger::INFO,
      message: "Test message",
      progname: nil,
      tags: nil
    })
  end

  it "inherits the parent logger's level" do
    logger.level = Logger::WARN
    local_logger = Lumberjack::LocalLogger.new(logger)
    expect(local_logger.level).to eq(Logger::WARN)
  end

  it "will log in the parent logger even if the parent logger has a higher threshold" do
    logger.level = :warn
    local_logger = Lumberjack::LocalLogger.new(logger)
    local_logger.level = :info
    expect(logger.level).to eq(Logger::WARN)
    local_logger.info("Test message")
    expect(logger.entries.first).to eq({
      severity: Logger::INFO,
      message: "Test message",
      progname: nil,
      tags: nil
    })
  end

  it "allows setting tags on the local logger" do
    local_logger = Lumberjack::LocalLogger.new(logger)
    local_logger.tag!(test: "value")
    local_logger.info("Test message")
    expect(logger.tags).to be_empty
    expect(logger.entries.first).to eq({
      severity: Logger::INFO,
      message: "Test message",
      progname: nil,
      tags: {"test" => "value"}
    })
  end

  it "allows setting the progname on the local logger" do
    local_logger = Lumberjack::LocalLogger.new(logger)
    local_logger.progname = "TestProgname"
    local_logger.info("Test message")
    expect(logger.progname).to be_nil
    expect(logger.entries.first).to eq({
      severity: Logger::INFO,
      message: "Test message",
      progname: "TestProgname",
      tags: nil
    })
  end
end
