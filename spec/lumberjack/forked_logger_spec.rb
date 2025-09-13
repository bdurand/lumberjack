# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::ForkedLogger do
  let(:logger) { TestContextLogger.new(Lumberjack::Context.new) }

  it "logs to the parent logger" do
    forked_logger = Lumberjack::ForkedLogger.new(logger)

    forked_logger.info("Test message")

    expect(logger.entries.first).to eq({
      severity: Logger::INFO,
      message: "Test message",
      progname: nil,
      attributes: nil
    })
  end

  it "inherits the parent logger's level" do
    logger.level = Logger::WARN
    forked_logger = Lumberjack::ForkedLogger.new(logger)
    expect(forked_logger.level).to eq(Logger::WARN)
  end

  it "will log in the parent logger even if the parent logger has a higher threshold" do
    logger.level = :warn
    forked_logger = Lumberjack::ForkedLogger.new(logger)
    forked_logger.level = :info
    expect(logger.level).to eq(Logger::WARN)
    forked_logger.info("Test message")
    expect(logger.entries.first).to eq({
      severity: Logger::INFO,
      message: "Test message",
      progname: nil,
      attributes: nil
    })
  end

  it "allows setting attributes on the local logger" do
    forked_logger = Lumberjack::ForkedLogger.new(logger)
    forked_logger.tag!(test: "value")
    forked_logger.info("Test message")
    expect(logger.attributes).to be_empty
    expect(logger.entries.first).to eq({
      severity: Logger::INFO,
      message: "Test message",
      progname: nil,
      attributes: {"test" => "value"}
    })
  end

  it "does not bleed attributes to the parent logger contexts" do
    forked_logger = Lumberjack::ForkedLogger.new(logger)
    forked_logger.tag_all_contexts(test: "value")
    expect(logger.attributes).to be_empty

    forked_logger.tag(foo: "bar") do
      forked_logger.tag_all_contexts(test: "value")
    end
    expect(logger.attributes).to be_empty
  end

  it "does not bleed attributes to the default context" do
    forked_logger = Lumberjack::ForkedLogger.new(logger)
    forked_logger.tag(test: "value")
    expect(forked_logger.attributes).to be_empty

    forked_logger.tag_all_contexts(test: "value")
    expect(forked_logger.attributes).to be_empty

    forked_logger.tag(foo: "bar") do
      forked_logger.tag_all_contexts(test: "value")
    end
    expect(forked_logger.attributes).to be_empty
  end

  it "allows setting the progname on the local logger" do
    forked_logger = Lumberjack::ForkedLogger.new(logger)
    forked_logger.progname = "TestProgname"
    forked_logger.info("Test message")
    expect(logger.progname).to be_nil
    expect(logger.entries.first).to eq({
      severity: Logger::INFO,
      message: "Test message",
      progname: "TestProgname",
      attributes: nil
    })
  end
end
