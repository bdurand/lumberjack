require 'spec_helper'

describe Lumberjack::Formatter do

  let(:formatter){ Lumberjack::Formatter.new }

  it "should have a default set of formatters" do
    expect(formatter.format("abc")).to eq("abc")
    expect(formatter.format([1, 2, 3])).to eq([1, 2, 3])
    expect(formatter.format(ArgumentError.new("boom"))).to eq("ArgumentError: boom")
  end

  it "should be able to add a formatter object for a class" do
    formatter.add(Numeric, lambda{|obj| "number: #{obj}"})
    expect(formatter.format(10)).to eq("number: 10")
  end

  it "should be able to add a formatter object for a module" do
    formatter.add(Enumerable, lambda{|obj| "list: #{obj.inspect}"})
    expect(formatter.format([1, 2])).to eq("list: [1, 2]")
  end

  it "should be able to add a formatter block for a class" do
    formatter.add(Numeric){|obj| "number: #{obj}"}
    expect(formatter.format(10)).to eq("number: 10")
  end

  it "should be able to remove a formatter for a class" do
    formatter.remove(String)
    expect(formatter.format("abc")).to eq("\"abc\"")
  end

  it "should be able to chain add and remove calls" do
    expect(formatter.remove(String)).to eq(formatter)
    expect(formatter.add(String, Lumberjack::Formatter::StringFormatter.new)).to eq(formatter)
  end

  it "should format an object based on the class hierarchy" do
    formatter.add(Numeric){|obj| "number: #{obj}"}
    formatter.add(Integer){|obj| "fixed number: #{obj}"}
    expect(formatter.format(10)).to eq("fixed number: 10")
    expect(formatter.format(10.1)).to eq("number: 10.1")
  end

  it "should have a default formatter" do
    formatter.remove(Object)
    expect(formatter.format(:test)).to eq(":test")
  end

end
