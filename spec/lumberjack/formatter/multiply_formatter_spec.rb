# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Formatter::MultiplyFormatter do
  it "is registered as :multiply" do
    expect(Lumberjack::FormatterRegistry.formatter(:multiply, 2)).to be_a(Lumberjack::Formatter::MultiplyFormatter)
  end

  it "multiplies a numeric value" do
    formatter = Lumberjack::Formatter::MultiplyFormatter.new(2)
    expect(formatter.call(5)).to eq(10)
  end

  it "rounds the result if decimals are specified" do
    formatter = Lumberjack::Formatter::MultiplyFormatter.new(2, 1)
    expect(formatter.call(5.125)).to eq(10.3)
  end

  it "can round to integer if decimals is zero" do
    formatter = Lumberjack::Formatter::MultiplyFormatter.new(2, 0)
    result = formatter.call(5.9)
    expect(result).to eq(12)
    expect(result).to be_a(Integer)
  end

  it "returns the original value if not numeric" do
    formatter = Lumberjack::Formatter::MultiplyFormatter.new(2)
    expect(formatter.call("not a number")).to eq("not a number")
    expect(formatter.call(nil)).to eq(nil)
  end
end
