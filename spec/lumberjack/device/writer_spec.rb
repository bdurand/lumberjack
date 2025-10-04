# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Device::Writer do
  let(:time_string) { "2011-01-15T14:23:45.123" }
  let(:time) { Time.parse(time_string) }
  let(:stream) { StringIO.new }
  let(:entry) { Lumberjack::LogEntry.new(time, Logger::INFO, "test message", "app", 12345, "foo" => "ABCD") }

  let(:io_class) do
    Class.new do
      attr_reader :string
      attr_accessor :sync
      attr_accessor :path

      def initialize
        @string = +""
        @buffer = +""
        @sync = false
      end

      def write(string)
        @buffer << string
      end

      def flush
        @string << @buffer
        @buffer = +""
      end
    end
  end

  it "should sync the stream and flush it when the device is flushed" do
    # Create an IO like object that require flush to be called
    io = io_class.new

    device = Lumberjack::Device::Writer.new(io, template: "{{message}}")
    device.write(entry)
    expect(io.string).to eq("")
    device.flush
    expect(io.string).to eq("test message#{Lumberjack::LINE_SEPARATOR}")
  end

  it "sets io sync by default" do
    io = io_class.new
    Lumberjack::Device::Writer.new(io)
    expect(io.sync).to be true
  end

  it "disables io sync if autoflush is false" do
    io = io_class.new
    Lumberjack::Device::Writer.new(io, autoflush: false)
    expect(io.sync).to be false
  end

  describe "#path" do
    it "can get the file path for the underlying stream" do
      io = io_class.new
      io.path = "/path/to/logfile.log"
      device = Lumberjack::Device::Writer.new(io)
      expect(device.path).to eq("/path/to/logfile.log")
    end

    it "returns nil if the stream does not have a path" do
      device = Lumberjack::Device::Writer.new(StringIO.new)
      expect(device.path).to be_nil
    end
  end

  it "should write entries out to the stream with a default template" do
    device = Lumberjack::Device::Writer.new(stream)
    device.write(entry)
    device.flush
    expect(stream.string).to eq("[2011-01-15T14:23:45.123 INFO  app(12345)] test message [foo:ABCD]#{Lumberjack::LINE_SEPARATOR}")
  end

  it "should write entries out to the stream with a custom template" do
    device = Lumberjack::Device::Writer.new(stream, template: "{{message}}")
    device.write(entry)
    device.flush
    expect(stream.string).to eq("test message#{Lumberjack::LINE_SEPARATOR}")
  end

  it "should be able to specify the time format for the template" do
    device = Lumberjack::Device::Writer.new(stream, time_format: :microseconds)
    device.write(entry)
    device.flush
    expect(stream.string).to eq("[2011-01-15T14:23:45.123000 INFO  app(12345)] test message [foo:ABCD]#{Lumberjack::LINE_SEPARATOR}")
  end

  it "should be able to specify a block template for log entries" do
    device = Lumberjack::Device::Writer.new(stream, template: lambda { |e| e.message.upcase })
    device.write(entry)
    device.flush
    expect(stream.string).to eq("TEST MESSAGE#{Lumberjack::LINE_SEPARATOR}")
  end

  it "can write to a template registry template" do
    device = Lumberjack::Device::Writer.new(stream, template: :local, exclude_pid: false)
    device.write(entry)
    device.flush
    template = Lumberjack::LocalLogTemplate.new(exclude_pid: false)
    expect(stream.string).to eq(template.call(entry))
  end

  it "should write to STDERR if an error is raised when flushing to the stream" do
    stderr = $stderr
    $stderr = StringIO.new
    begin
      device = Lumberjack::Device::Writer.new(stream, template: "{{message}}")
      expect(stream).to receive(:write).and_raise(StandardError.new("Cannot write to stream"))
      device.write(entry)
      device.flush
      expect($stderr.string).to include("test message#{Lumberjack::LINE_SEPARATOR}")
      expect($stderr.string).to include("StandardError: Cannot write to stream")
    ensure
      $stderr = stderr
    end
  end

  describe "multi line messages" do
    let(:message) { "line 1#{Lumberjack::LINE_SEPARATOR}line 2#{Lumberjack::LINE_SEPARATOR}line 3" }
    let(:entry) { Lumberjack::LogEntry.new(time, Logger::INFO, message, "app", 12345, "foo" => "ABCD") }

    it "should have a default template for multiline messages" do
      device = Lumberjack::Device::Writer.new(stream)
      device.write(entry)
      device.flush
      expect(stream.string.split(Lumberjack::LINE_SEPARATOR)).to eq(["[2011-01-15T14:23:45.123 INFO  app(12345)] line 1 [foo:ABCD]", "> line 2", "> line 3"])
    end

    it "should be able to specify a template for multiple line messages" do
      device = Lumberjack::Device::Writer.new(stream, additional_lines: " // {{message}}")
      device.write(entry)
      device.flush
      expect(stream.string).to eq("[2011-01-15T14:23:45.123 INFO  app(12345)] line 1 [foo:ABCD] // line 2 // line 3#{Lumberjack::LINE_SEPARATOR}")
    end
  end

  describe "colorized entries" do
    it "should write entries out to the stream with colorized severity" do
      device = Lumberjack::Device::Writer.new(stream, colorize: true)
      entry = Lumberjack::LogEntry.new(time, Logger::INFO, "line 1#{Lumberjack::LINE_SEPARATOR}line 2#", "app", 12345, "foo" => "ABCD")
      device.write(entry)
      expect(stream.string).to eq("\e7\e[38;5;33m[2011-01-15T14:23:45.123 INFO  app(12345)] line 1 [foo:ABCD]\e8#{Lumberjack::LINE_SEPARATOR}\e7\e[38;5;33m> line 2#\e8#{Lumberjack::LINE_SEPARATOR}")
    end
  end

  describe "#dev" do
    it "returns the underlying stream" do
      stream = StringIO.new
      device = Lumberjack::Device::Writer.new(stream)
      expect(device.dev).to eq(stream)
    end
  end
end
