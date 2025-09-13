# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Formatter::TruncateFormatter do
  it "is registered as :truncate" do
    expect(Lumberjack::FormatterRegistry.formatter(:truncate)).to be_a(Lumberjack::Formatter::TruncateFormatter)
  end

  it "should truncate a string longer than the limit" do
    formatter = Lumberjack::Formatter::TruncateFormatter.new(9)
    expect(formatter.call("1234567890")).to eq "12345678…"
  end

  it "should not truncate a string that is shorter than the length" do
    formatter = Lumberjack::Formatter::TruncateFormatter.new(9)
    expect(formatter.call("123456789")).to eq "123456789"
  end

  it "should pass through objects that are not strings" do
    formatter = Lumberjack::Formatter::TruncateFormatter.new(9)
    expect(formatter.call(:abcdefghijklmnop)).to eq :abcdefghijklmnop
  end
end
