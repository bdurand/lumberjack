# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Formatter::ExceptionFormatter do
  it "should convert an exception without a backtrace to a string" do
    e = ArgumentError.new("not expected")
    formatter = Lumberjack::Formatter::ExceptionFormatter.new
    expect(formatter.call(e)).to eq("ArgumentError: not expected")
  end

  it "should convert an exception with a backtrace to a string" do
    raise ArgumentError.new("not expected")
  rescue => e
    formatter = Lumberjack::Formatter::ExceptionFormatter.new
    expect(formatter.call(e)).to eq("ArgumentError: not expected#{Lumberjack::LINE_SEPARATOR}  #{e.backtrace.join(Lumberjack::LINE_SEPARATOR + "  ")}")
  end

  it "should clean the backtrace" do
    raise ArgumentError.new("not expected")
  rescue => e
    formatter = Lumberjack::Formatter::ExceptionFormatter.new
    formatter.backtrace_cleaner = lambda { |lines| ["redacted: #{lines.size}"] }
    expect(formatter.call(e)).to eq("ArgumentError: not expected#{Lumberjack::LINE_SEPARATOR}  redacted: #{e.backtrace.size}")
  end
end
