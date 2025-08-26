# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Formatter::StringFormatter do
  it "is registered as :string" do
    expect(Lumberjack::FormatterRegistry.formatter(:string)).to be_a(Lumberjack::Formatter::StringFormatter)
  end

  it "should format objects as string by calling their to_s method" do
    formatter = Lumberjack::Formatter::StringFormatter.new
    expect(formatter.call("abc")).to eq("abc")
    expect(formatter.call(:test)).to eq("test")
    expect(formatter.call(1)).to eq("1")
  end
end
