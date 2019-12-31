require 'spec_helper'

describe Lumberjack::Severity do
  
  it "should convert a level to a label" do
    expect(Lumberjack::Severity.level_to_label(Lumberjack::Severity::DEBUG)).to eq("DEBUG")
    expect(Lumberjack::Severity.level_to_label(Lumberjack::Severity::INFO)).to eq("INFO")
    expect(Lumberjack::Severity.level_to_label(Lumberjack::Severity::WARN)).to eq("WARN")
    expect(Lumberjack::Severity.level_to_label(Lumberjack::Severity::ERROR)).to eq("ERROR")
    expect(Lumberjack::Severity.level_to_label(Lumberjack::Severity::FATAL)).to eq("FATAL")
    expect(Lumberjack::Severity.level_to_label(-1)).to eq("UNKNOWN")
  end
  
  it "should convert a label to a level" do
    expect(Lumberjack::Severity.label_to_level("DEBUG")).to eq(Lumberjack::Severity::DEBUG)
    expect(Lumberjack::Severity.label_to_level(:info)).to eq(Lumberjack::Severity::INFO)
    expect(Lumberjack::Severity.label_to_level(:warn)).to eq(Lumberjack::Severity::WARN)
    expect(Lumberjack::Severity.label_to_level("Error")).to eq(Lumberjack::Severity::ERROR)
    expect(Lumberjack::Severity.label_to_level("FATAL")).to eq(Lumberjack::Severity::FATAL)
    expect(Lumberjack::Severity.label_to_level("???")).to eq(Lumberjack::Severity::UNKNOWN)
  end
  
end
