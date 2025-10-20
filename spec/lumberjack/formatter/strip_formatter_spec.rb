# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Formatter::StripFormatter do
  it "is registered as :strip" do
    expect(Lumberjack::FormatterRegistry.formatter(:strip)).to be_a(Lumberjack::Formatter::StripFormatter)
  end

  it "should format objects as strings with leading and trailing whitespace removed" do
    formatter = Lumberjack::Formatter::StripFormatter.new
    expect(formatter.call(" abc \n")).to eq("abc")
    expect(formatter.call(:test)).to eq("test")
    expect(formatter.call(1)).to eq("1")
  end
end
