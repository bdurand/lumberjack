require 'spec_helper'

describe Lumberjack::Severity do

  it "should convert a level to a label" do
    expect(Lumberjack::Severity.level_to_label(Logger::DEBUG)).to eq("DEBUG")
    expect(Lumberjack::Severity.level_to_label(Logger::INFO)).to eq("INFO")
    expect(Lumberjack::Severity.level_to_label(Logger::WARN)).to eq("WARN")
    expect(Lumberjack::Severity.level_to_label(Logger::ERROR)).to eq("ERROR")
    expect(Lumberjack::Severity.level_to_label(Logger::FATAL)).to eq("FATAL")
    expect(Lumberjack::Severity.level_to_label(100)).to eq("UNKNOWN")
  end

  it "should convert a label to a level" do
    expect(Lumberjack::Severity.label_to_level("DEBUG")).to eq(Logger::DEBUG)
    expect(Lumberjack::Severity.label_to_level(:info)).to eq(Logger::INFO)
    expect(Lumberjack::Severity.label_to_level(:warn)).to eq(Logger::WARN)
    expect(Lumberjack::Severity.label_to_level("Error")).to eq(Logger::ERROR)
    expect(Lumberjack::Severity.label_to_level("FATAL")).to eq(Logger::FATAL)
    expect(Lumberjack::Severity.label_to_level("???")).to eq(Logger::UNKNOWN)
  end

end
