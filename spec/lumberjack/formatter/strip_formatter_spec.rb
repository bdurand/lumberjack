require "spec_helper"

describe Lumberjack::Formatter::StripFormatter do
  it "should format objects as strings with leading and trailing whitespace removed" do
    formatter = Lumberjack::Formatter::StripFormatter.new
    expect(formatter.call(" abc \n")).to eq("abc")
    expect(formatter.call(:test)).to eq("test")
    expect(formatter.call(1)).to eq("1")
  end
end
