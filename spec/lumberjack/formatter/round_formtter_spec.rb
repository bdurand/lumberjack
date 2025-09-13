# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Formatter::RoundFormatter do
  it "is registered as :round" do
    expect(Lumberjack::FormatterRegistry.formatter(:round, 1)).to be_a(Lumberjack::Formatter::RoundFormatter)
  end

  it "should round a numeric value" do
    formatter = Lumberjack::Formatter::RoundFormatter.new
    expect(formatter.call(1.23456789)).to eq(1.235)
  end

  it "should work with an integer value" do
    formatter = Lumberjack::Formatter::RoundFormatter.new
    expect(formatter.call(10)).to eq(10)
  end

  it "should round a numeric value with specified precision" do
    formatter = Lumberjack::Formatter::RoundFormatter.new(1)
    expect(formatter.call(1.234)).to eq(1.2)
  end

  it "should return non-numeric values unchanged" do
    formatter = Lumberjack::Formatter::RoundFormatter.new
    expect(formatter.call("not a number")).to eq("not a number")
    expect(formatter.call(nil)).to eq(nil)
    expect(formatter.call([])).to eq([])
  end
end
