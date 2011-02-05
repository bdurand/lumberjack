require 'spec_helper'

describe Lumberjack::LogEntry do
  
  it "should have a time" do
    t = Time.now
    entry = Lumberjack::LogEntry.new(t, Lumberjack::Severity::INFO, "test", "app", 1500, "ABCD")
    entry.time.should == t
  end
  
  it "should have a severity" do
    entry = Lumberjack::LogEntry.new(Time.now, Lumberjack::Severity::INFO, "test", "app", 1500, "ABCD")
    entry.severity.should == Lumberjack::Severity::INFO
  end
  
  it "should get the severity as a string" do
    Lumberjack::LogEntry.new(Time.now, Lumberjack::Severity::DEBUG, "test", "app", 1500, nil).severity_label.should == "DEBUG"
    Lumberjack::LogEntry.new(Time.now, Lumberjack::Severity::INFO, "test", "app", 1500, nil).severity_label.should == "INFO"
    Lumberjack::LogEntry.new(Time.now, Lumberjack::Severity::WARN, "test", "app", 1500, nil).severity_label.should == "WARN"
    Lumberjack::LogEntry.new(Time.now, Lumberjack::Severity::ERROR, "test", "app", 1500, nil).severity_label.should == "ERROR"
    Lumberjack::LogEntry.new(Time.now, Lumberjack::Severity::FATAL, "test", "app", 1500, nil).severity_label.should == "FATAL"
    Lumberjack::LogEntry.new(Time.now, -1, "test", "app", 1500, nil).severity_label.should == "UNKNOWN"
    Lumberjack::LogEntry.new(Time.now, 1000, "test", "app", 1500, nil).severity_label.should == "UNKNOWN"
  end
  
  it "should have a message" do
    entry = Lumberjack::LogEntry.new(Time.now, Lumberjack::Severity::INFO, "test", "app", 1500, "ABCD")
    entry.message.should == "test"
  end
  
  it "should have a progname" do
    entry = Lumberjack::LogEntry.new(Time.now, Lumberjack::Severity::INFO, "test", "app", 1500, "ABCD")
    entry.progname.should == "app"
  end
  
  it "should have a pid" do
    entry = Lumberjack::LogEntry.new(Time.now, Lumberjack::Severity::INFO, "test", "app", 1500, "ABCD")
    entry.pid.should == 1500
  end
  
  it "should have a unit_of_work_id" do
    entry = Lumberjack::LogEntry.new(Time.now, Lumberjack::Severity::INFO, "test", "app", 1500, "ABCD")
    entry.unit_of_work_id.should == "ABCD"
  end
  
  it "should be converted to a string" do
    t = Time.parse("2011-01-29T12:15:32")
    entry = Lumberjack::LogEntry.new(t, Lumberjack::Severity::INFO, "test", "app", 1500, "ABCD")
    entry.to_s.should == "2011-01-29T12:15:32 INFO [app(1500) #ABCD] test"
  end

end
