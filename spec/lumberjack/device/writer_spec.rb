require "spec_helper"

describe Lumberjack::Device::Writer do
  let(:time_string) { "2011-01-15T14:23:45.123" }
  let(:time) { Time.parse(time_string) }
  let(:stream) { StringIO.new }
  let(:entry) { Lumberjack::LogEntry.new(time, Logger::INFO, "test message", "app", 12345, "unit_of_work_id" => "ABCD") }

  it "should buffer output and not write directly to the stream" do
    device = Lumberjack::Device::Writer.new(stream, template: ":message", buffer_size: 32767)
    device.write(entry)
    expect(stream.string).to eq("")
    device.flush
    expect(stream.string).to eq("test message#{Lumberjack::LINE_SEPARATOR}")
  end

  it "should flush the buffer when it gets to the specified size" do
    device = Lumberjack::Device::Writer.new(stream, buffer_size: 15, template: ":message")
    device.write(entry)
    expect(stream.string).to eq("")
    device.write(entry)
    expect(stream.string).to eq("test message#{Lumberjack::LINE_SEPARATOR}test message#{Lumberjack::LINE_SEPARATOR}")
  end

  it "should sync the stream and flush it when the device is flushed" do
    # Create an IO like object that require flush to be called
    io = Object.new
    # rubocop:disable Style/TrivialAccessors
    def io.init
      @string = ""
      @buffer = ""
      @sync = false
    end

    def io.write(string)
      @buffer << string
    end

    def io.flush
      @string << @buffer
      @buffer = ""
    end

    def io.string
      @string
    end

    def io.sync=(val)
      @sync = val
    end

    def io.sync
      @sync
    end
    # rubocop:enable Style/TrivialAccessors

    io.init

    device = Lumberjack::Device::Writer.new(io, template: ":message", buffer_size: 32767)
    device.write(entry)
    expect(io.string).to eq("")
    device.flush
    expect(io.string).to eq("test message#{Lumberjack::LINE_SEPARATOR}")
    expect(io.sync).to eq(true)
  end

  it "should be able to set the buffer size" do
    device = Lumberjack::Device::Writer.new(stream, buffer_size: 15)
    expect(device.buffer_size).to eq(15)
    device.buffer_size = 100
    expect(device.buffer_size).to eq(100)
  end

  it "should have a default buffer size of 0" do
    device = Lumberjack::Device::Writer.new(stream)
    expect(device.buffer_size).to eq(0)
  end

  it "should write entries out to the stream with a default template" do
    device = Lumberjack::Device::Writer.new(stream)
    device.write(entry)
    device.flush
    expect(stream.string).to eq("[2011-01-15T14:23:45.123 INFO app(12345) #ABCD] test message#{Lumberjack::LINE_SEPARATOR}")
  end

  it "should write entries out to the stream with a custom template" do
    device = Lumberjack::Device::Writer.new(stream, template: ":message")
    device.write(entry)
    device.flush
    expect(stream.string).to eq("test message#{Lumberjack::LINE_SEPARATOR}")
  end

  it "should be able to specify the time format for the template" do
    device = Lumberjack::Device::Writer.new(stream, time_format: :microseconds)
    device.write(entry)
    device.flush
    expect(stream.string).to eq("[2011-01-15T14:23:45.123000 INFO app(12345) #ABCD] test message#{Lumberjack::LINE_SEPARATOR}")
  end

  it "should be able to specify a block template for log entries" do
    device = Lumberjack::Device::Writer.new(stream, template: lambda { |e| e.message.upcase })
    device.write(entry)
    device.flush
    expect(stream.string).to eq("TEST MESSAGE#{Lumberjack::LINE_SEPARATOR}")
  end

  it "should write to STDERR if an error is raised when flushing to the stream" do
    stderr = $stderr
    $stderr = StringIO.new
    begin
      device = Lumberjack::Device::Writer.new(stream, template: ":message")
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
    let(:entry) { Lumberjack::LogEntry.new(time, Logger::INFO, message, "app", 12345, "unit_of_work_id" => "ABCD") }

    it "should have a default template for multiline messages" do
      device = Lumberjack::Device::Writer.new(stream)
      device.write(entry)
      device.flush
      expect(stream.string.split(Lumberjack::LINE_SEPARATOR)).to eq(["[2011-01-15T14:23:45.123 INFO app(12345) #ABCD] line 1", "> [#ABCD] line 2", "> [#ABCD] line 3"])
    end

    it "should be able to specify a template for multiple line messages" do
      device = Lumberjack::Device::Writer.new(stream, additional_lines: " // :message")
      device.write(entry)
      device.flush
      expect(stream.string).to eq("[2011-01-15T14:23:45.123 INFO app(12345) #ABCD] line 1 // line 2 // line 3#{Lumberjack::LINE_SEPARATOR}")
    end
  end
end
