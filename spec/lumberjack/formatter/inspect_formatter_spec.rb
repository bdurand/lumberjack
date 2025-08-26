# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Formatter::InspectFormatter do
  it "is registered as :inspect" do
    expect(Lumberjack::FormatterRegistry.formatter(:inspect)).to be_a(Lumberjack::Formatter::InspectFormatter)
  end

  it "should format objects as string by calling their inspect method" do
    formatter = Lumberjack::Formatter::InspectFormatter.new
    expect(formatter.call("abc")).to eq("\"abc\"")
    expect(formatter.call(:test)).to eq(":test")
    expect(formatter.call(1)).to eq("1")
    expect(formatter.call([:a, 1, "b"])).to eq([:a, 1, "b"].inspect)
  end
end
