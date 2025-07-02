# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Formatter::RedactFormatter do
  it "should redact long strings" do
    formatter = Lumberjack::Formatter::RedactFormatter.new
    expect(formatter.call("1234567890")).to eq("12******90")
  end

  it "should redact shorter strings with fewer hints" do
    formatter = Lumberjack::Formatter::RedactFormatter.new
    expect(formatter.call("123456")).to eq("1****6")
  end

  it "should fully redact very short strings" do
    formatter = Lumberjack::Formatter::RedactFormatter.new
    expect(formatter.call("123")).to eq("*****")
  end

  it "should return non-string values unchanged" do
    formatter = Lumberjack::Formatter::RedactFormatter.new
    expect(formatter.call(123)).to eq(123)
  end
end
