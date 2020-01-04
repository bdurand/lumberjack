require 'spec_helper'

describe Lumberjack::Device::SizeRollingLogFile do

  before :all do
    create_tmp_dir
  end
  
  after :all do
    delete_tmp_dir
  end
  
  before :each do
    delete_tmp_files
  end

  it "should roll a file when it gets to a specified size" do
    log_file = File.join(tmp_dir, "a#{rand(1000000000)}.log")
    device = Lumberjack::Device::SizeRollingLogFile.new(log_file, :max_size => 40, :template => ":message", :min_roll_check => 0)
    logger = Lumberjack::Logger.new(device, :buffer_size => 2)
    4.times do |i|
      logger.error("test message #{i + 1}")
      logger.flush
    end
    logger.close
    
    expect(File.read("#{log_file}.1").split(Lumberjack::LINE_SEPARATOR)).to eq(["test message 1", "test message 2", "test message 3"])
    expect(File.read(log_file)).to eq("test message 4#{Lumberjack::LINE_SEPARATOR}")
  end
  
  it "should be able to specify the max size in kilobytes" do
    log_file = File.join(tmp_dir, "b#{rand(1000000000)}.log")
    device = Lumberjack::Device::SizeRollingLogFile.new(log_file, :max_size => "32K", :min_roll_check => 0)
    expect(device.max_size).to eq(32768)
  end
  
  it "should be able to specify the max size in megabytes" do
    log_file = File.join(tmp_dir, "c#{rand(1000000000)}.log")
    device = Lumberjack::Device::SizeRollingLogFile.new(log_file, :max_size => "100M", :min_roll_check => 0)
    expect(device.max_size).to eq(104_857_600)
  end
  
  it "should be able to specify the max size in gigabytes" do
    log_file = File.join(tmp_dir, "d#{rand(1000000000)}.log")
    device = Lumberjack::Device::SizeRollingLogFile.new(log_file, :max_size => "1G", :min_roll_check => 0)
    expect(device.max_size).to eq(1_073_741_824)
  end
  
  it "should figure out the next archive file name available" do
    log_file = File.join(tmp_dir, "filename.log")
    (3..11).each do |i|
      File.open("#{log_file}.#{i}", 'w'){|f| f.write(i.to_s)}
    end
    device = Lumberjack::Device::SizeRollingLogFile.new(log_file, :max_size => "100M", :min_roll_check => 0)
    expect(device.archive_file_suffix).to eq("12")
  end

end
