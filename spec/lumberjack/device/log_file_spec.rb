require "spec_helper"

describe Lumberjack::Device::LogFile do
  before :all do
    create_tmp_dir
  end

  after :all do
    delete_tmp_dir
  end

  before :each do
    delete_tmp_files
  end

  it "should append to a file" do
    log_file = File.join(tmp_dir, "a#{rand(1000000000)}.log")
    File.open(log_file, "w") do |f|
      f.puts("Existing contents")
    end

    device = Lumberjack::Device::LogFile.new(log_file, template: ":message")
    device.write(Lumberjack::LogEntry.new(Time.now, 1, "New log entry", nil, $$, nil))
    device.close

    expect(File.read(log_file)).to eq("Existing contents\nNew log entry#{Lumberjack::LINE_SEPARATOR}")
  end

  it "properly handles messages with broken UTF-8 characters" do
    log_file = File.join(tmp_dir, "a#{rand(1000000000)}.log")
    device = Lumberjack::Device::LogFile.new(log_file, keep: 2, buffer_size: 32767)

    message = [0xC4, 0x90, 0xE1, 0xBB].pack("c*").force_encoding "ASCII-8BIT"
    entry = Lumberjack::LogEntry.new(Time.now, 1, message, nil, $$, nil)
    device.write entry

    message = "проверка"
    entry = Lumberjack::LogEntry.new(Time.now, 1, message, nil, $$, nil)
    device.write entry

    expect do
      device.flush
    end.to_not raise_error
  end

  it "should reopen the file" do
    log_file = File.join(tmp_dir, "a#{rand(1000000000)}.log")
    device = Lumberjack::Device::LogFile.new(log_file, template: ":message")
    device.write(Lumberjack::LogEntry.new(Time.now, 1, "message 1", nil, $$, nil))
    device.close
    device.reopen
    device.write(Lumberjack::LogEntry.new(Time.now, 1, "message 2", nil, $$, nil))
    device.close
    expect(File.read(log_file)).to eq("message 1#{Lumberjack::LINE_SEPARATOR}message 2#{Lumberjack::LINE_SEPARATOR}")
  end
end
