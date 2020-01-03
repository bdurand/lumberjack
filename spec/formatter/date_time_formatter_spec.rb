require 'spec_helper'

describe Lumberjack::Formatter::DateTimeFormatter do

  it "should format a time object" do
    time = Time.now
    formatter = Lumberjack::Formatter::DateTimeFormatter.new("%Y-%m-%d %H:%M")
    expect(formatter.call(time)).to eq time.strftime("%Y-%m-%d %H:%M")
  end

  it "should format a date object" do
    date = Date.today
    formatter = Lumberjack::Formatter::DateTimeFormatter.new("%Y-%m-%d %H:%M")
    expect(formatter.call(date)).to eq date.strftime("%Y-%m-%d %H:%M")
  end

  it "should format a datetime object" do
    datetime = DateTime.now
    formatter = Lumberjack::Formatter::DateTimeFormatter.new("%Y-%m-%d %H:%M")
    expect(formatter.call(datetime)).to eq datetime.strftime("%Y-%m-%d %H:%M")
  end

  it "should not format a non date or time" do
    formatter = Lumberjack::Formatter::DateTimeFormatter.new("%Y-%m-%d %H:%M")
    expect("foo").to eq "foo"
  end

  it "should use iso8601 by default" do
    time = Time.now
    formatter = Lumberjack::Formatter::DateTimeFormatter.new
    expect(formatter.call(time)).to eq time.iso8601
  end

end
