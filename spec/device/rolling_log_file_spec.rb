require 'spec_helper'

describe Lumberjack::Device::RollingLogFile do

  before :all do
    Lumberjack::Device::SizeRollingLogFile #needed by jruby
    create_tmp_dir
  end
  
  after :all do
    delete_tmp_dir
  end
  
  before :each do
    delete_tmp_files
  end
  
  let(:entry){ Lumberjack::LogEntry.new(Time.now, 1, "New log entry", nil, $$, nil) }

  it "should check for rolling the log file on flush" do
    device = Lumberjack::Device::RollingLogFile.new(File.join(tmp_dir, "test.log"), :buffer_size => 32767, :min_roll_check => 0)
    device.write(entry)
    expect(device).to receive(:roll_file?).twice.and_return(false)
    device.flush
    device.close
  end
  
  it "should roll the file by archiving the existing file and opening a new stream and calling after_roll" do
    log_file = File.join(tmp_dir, "test_2.log")
    device = Lumberjack::Device::RollingLogFile.new(log_file, :template => ":message", :buffer_size => 32767, :min_roll_check => 0)
    expect(device).to receive(:roll_file?).and_return(false, true)
    expect(device).to receive(:after_roll)
    device.stub(:archive_file_suffix => "rolled")
    device.write(entry)
    device.flush
    device.write(Lumberjack::LogEntry.new(Time.now, 1, "Another log entry", nil, $$, nil))
    device.close
    File.read("#{log_file}.rolled").should == "New log entry#{Lumberjack::LINE_SEPARATOR}"
    File.read(log_file).should == "Another log entry#{Lumberjack::LINE_SEPARATOR}"
  end
  
  it "should reopen the file if the stream inode doesn't match the file path inode" do
    log_file = File.join(tmp_dir, "test_3.log")
    device = Lumberjack::Device::RollingLogFile.new(log_file, :template => ":message", :min_roll_check => 0)
    device.stub(:roll_file? => false)
    device.write(entry)
    device.flush
    File.rename(log_file, "#{log_file}.rolled")
    device.flush
    device.write(Lumberjack::LogEntry.new(Time.now, 1, "Another log entry", nil, $$, nil))
    device.close
    File.read("#{log_file}.rolled").should == "New log entry#{Lumberjack::LINE_SEPARATOR}"
    File.read(log_file).should == "Another log entry#{Lumberjack::LINE_SEPARATOR}"
  end
  
  it "should roll the file properly with multiple thread and processes using it" do
    log_file = File.join(tmp_dir, "test_4.log")
    process_count = 8
    thread_count = 4
    entry_count = 400
    max_size = 128
    severity = Lumberjack::Severity::INFO
    message = "This is a test message that is written to the log file to indicate what the state of the application is."
    
    logger_test = lambda do
      device = Lumberjack::Device::SizeRollingLogFile.new(log_file, :max_size => max_size, :template => ":message", :buffer_size => 32767, :min_roll_check => 0)
      threads = []
      thread_count.times do
        threads << Thread.new do
          entry_count.times do |i|
            device.write(Lumberjack::LogEntry.new(Time.now, severity, message, "test", $$, nil))
            device.flush if i % 10 == 0
          end
          device.flush
        end
      end
      threads.each{|thread| thread.value}
      device.close
    end
    
    # Process.fork is unavailable on jruby so we need to use the java threads instead.
    if RUBY_PLATFORM.match(/java/)
      outer_threads = []
      process_count.times do
        outer_threads << Thread.new(&logger_test)
      end
      outer_threads.each{|thread| thread.value}
    else
      process_count.times do
        Process.fork(&logger_test)
      end
      Process.waitall
    end
    
    line_count = 0
    file_count = 0
    Dir.glob("#{log_file}*").each do |file|
      file_count += 1
      lines = File.read(file).split(Lumberjack::LINE_SEPARATOR)
      line_count += lines.size
      lines.each do |line|
        line.should == message
      end
    end
    
    file_count.should > 3
  end
  
  it "should only keep a specified number of archived log files" do
    log_file = File.join(tmp_dir, "test_5.log")
    device = Lumberjack::Device::RollingLogFile.new(log_file, :template => ":message", :keep => 2, :buffer_size => 32767, :min_roll_check => 0)
    expect(device).to receive(:roll_file?).and_return(false, true, true, true)
    expect(device).to receive(:archive_file_suffix).and_return("delete", "another", "keep")
    t = Time.now
    expect(File).to receive(:ctime).with("#{log_file}.delete").at_least(1).times.and_return(t + 1)
    expect(File).to receive(:ctime).with("#{log_file}.another").at_least(1).times.and_return(t + 2)
    expect(File).to receive(:ctime).with("#{log_file}.keep").at_least(1).times.and_return(t + 3)
    device.write(entry)
    device.flush
    device.write(entry)
    device.flush
    device.write(entry)
    device.flush
    device.write(entry)
    device.close
    Dir.glob("#{log_file}*").sort.should == [log_file, "#{log_file}.another", "#{log_file}.keep"]
  end

  context "when file is rolled" do
    let(:log_file) { File.join(tmp_dir, "test_6.log") }

    let(:device) do
      device = Lumberjack::Device::RollingLogFile.new(log_file, :template => ":message", :keep => 2, :buffer_size => 32767, :min_roll_check => 0)
      device.stub(:roll_file?).and_return(true)
      device.stub(:archive_file_suffix => "rolled")
      device
    end

    before do
      device.write(entry)
      device.flush
    end

    it "reopens file with proper encoding" do
      encoding = device.send(:stream).external_encoding
      expect(encoding).to_not be_nil
      expect(encoding.name).to eq "ASCII-8BIT"
    end
  end

end
