require 'spec_helper'

describe Lumberjack::Formatter::StringFormatter do

  it "should format objects as string by calling their to_s method" do
    formatter = Lumberjack::Formatter::StringFormatter.new
    expect(formatter.call("abc")).to eq("abc")
    expect(formatter.call(:test)).to eq("test")
    expect(formatter.call(1)).to eq("1")
  end

end
