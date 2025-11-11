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

  it "flushes the parent logger's device" do
    forked_logger = Lumberjack::ForkedLogger.new(logger)
    expect(logger).to receive(:flush)
    forked_logger.flush
  end

  it "inherits the parent logger's level" do
    logger.level = Logger::WARN
    forked_logger = Lumberjack::ForkedLogger.new(logger)
    expect(forked_logger.level).to eq(Logger::WARN)
  end

  it "inherits the parent logger's isolation level" do
    logger.isolation_level = :thread
    forked_logger = Lumberjack::ForkedLogger.new(logger)
    expect(forked_logger.isolation_level).to eq(:thread)
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
    logger = Lumberjack::Logger.new(:test)
    logger.tag!(foo: "bar", baz: "boo")
    forked_logger = Lumberjack::ForkedLogger.new(logger)

    forked_logger.tag!(test: "value", baz: "overridden")
    expect(logger.attributes).to eq({"foo" => "bar", "baz" => "boo"})

    forked_logger.info("Test message")
    entry = logger.device.entries.last
    expect(entry.attributes).to eq({
      "foo" => "bar",
      "baz" => "overridden",
      "test" => "value"
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

  it "returns the parent logger's device" do
    logger = Lumberjack::Logger.new(:test)
    forked_logger = Lumberjack::ForkedLogger.new(logger)
    expect(forked_logger.device).to eq(logger.device)
  end

  it "returns the parent logger's formatter" do
    formatter = Lumberjack::EntryFormatter.new
    logger = Lumberjack::Logger.new(:test, formatter: formatter)
    forked_logger = Lumberjack::ForkedLogger.new(logger)
    expect(forked_logger.formatter).to eq(logger.formatter)
  end

  context "when forking from a forked logger" do
    let(:original_logger) { Lumberjack::Logger.new(:test).tap { |logger| logger.tag!(foo: 1) } }
    let(:parent_forked_logger) { original_logger.fork(level: :warn, progname: "ParentForked", attributes: {bar: 2, baz: 3}) }
    let(:forked_logger) { parent_forked_logger.fork(level: :info, progname: "ChildForked", attributes: {baz: 4, qux: 5, wip: 7}) }

    it "uses the forked level" do
      forked_logger.info("Test message")
      expect(original_logger.device.entries.size).to eq(1)
    end

    it "uses the forked progname" do
      forked_logger.info("Test message")
      entry = original_logger.device.entries.last
      expect(entry.progname).to eq("ChildForked")
    end

    it "merges the forked attributes into the parent logger attributes" do
      forked_logger.info("Test message", tik: 6, wip: 8)
      entry = original_logger.device.entries.last
      expect(entry.attributes).to eq({
        "foo" => 1,
        "bar" => 2,
        "baz" => 4,
        "qux" => 5,
        "tik" => 6,
        "wip" => 8
      })
    end
  end
end
