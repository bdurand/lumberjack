require 'spec_helper'

describe Lumberjack::Device::DateRollingLogFile do

  before :all do
    create_tmp_dir
  end
  
  after :all do
    delete_tmp_dir
  end
  
  before :each do
    delete_tmp_files
  end
  
  let(:one_day){ 60 * 60 * 24 }
  
  it "should roll the file daily" do
    now = Time.now
    log_file = File.join(tmp_dir, "a#{rand(1000000000)}.log")
    device = Lumberjack::Device::DateRollingLogFile.new(log_file, :roll => :daily, :template => ":message", :min_roll_check => 0)
    logger = Lumberjack::Logger.new(device, :buffer_size => 2)
    Timecop.travel(now) do
      logger.error("test day one")
      logger.flush
    end
    Timecop.travel(now + one_day) do
      logger.error("test day two")
      logger.close
    end
  
    File.read("#{log_file}.#{now.to_date.strftime('%Y-%m-%d')}").should == "test day one#{Lumberjack::LINE_SEPARATOR}"
    File.read(log_file).should == "test day two#{Lumberjack::LINE_SEPARATOR}"
  end

  it "should roll the file weekly" do
    now = Time.now
    log_file = File.join(tmp_dir, "b#{rand(1000000000)}.log")
    device = Lumberjack::Device::DateRollingLogFile.new(log_file, :roll => :weekly, :template => ":message", :min_roll_check => 0)
    logger = Lumberjack::Logger.new(device, :buffer_size => 2)
    Timecop.freeze(now) do
      logger.error("test week one")
      logger.flush
    end
    Timecop.freeze(now + (7 * one_day)) do
      logger.error("test week two")
      logger.close
    end
    
    File.read("#{log_file}.#{now.to_date.strftime('week-of-%Y-%m-%d')}").should == "test week one#{Lumberjack::LINE_SEPARATOR}"
    File.read(log_file).should == "test week two#{Lumberjack::LINE_SEPARATOR}"
  end

  it "should roll the file monthly" do
    now = Time.now
    log_file = File.join(tmp_dir, "c#{rand(1000000000)}.log")
    device = Lumberjack::Device::DateRollingLogFile.new(log_file, :roll => :monthly, :template => ":message", :min_roll_check => 0)
    logger = Lumberjack::Logger.new(device, :buffer_size => 2)
    Timecop.freeze(now) do
      logger.error("test month one")
      logger.flush
    end
    Timecop.freeze(now + (31 * one_day)) do
      logger.error("test month two")
      logger.close
    end
  
    File.read("#{log_file}.#{now.to_date.strftime('%Y-%m')}").should == "test month one#{Lumberjack::LINE_SEPARATOR}"
    File.read(log_file).should == "test month two#{Lumberjack::LINE_SEPARATOR}"
  end

end
