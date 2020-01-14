require "spec_helper"

describe Lumberjack::TagFormatter do

  let(:tags) { {"foo" => "bar", "baz" => "boo", "count" => 1} }

  it "should do nothing by default" do
    tag_formatter = Lumberjack::TagFormatter.new
    expect(tag_formatter.format(tags)).to eq tags
  end

  it "should have a default formatter as a Formatter" do
    formatter = Lumberjack::Formatter.new.clear.add(String, :inspect)
    tag_formatter = Lumberjack::TagFormatter.new.default(formatter)
    expect(tag_formatter.format(tags)).to eq({"foo" => '"bar"', "baz" => '"boo"', "count" => 1})
  end

  it "should be able to add tag name specific formatters"  do
    formatter = Lumberjack::Formatter.new.clear.add(String, :inspect)
    tag_formatter = Lumberjack::TagFormatter.new.add(:foo, formatter)
    expect(tag_formatter.format(tags)).to eq({"foo" => '"bar"', "baz" => "boo", "count" => 1})

    tag_formatter.remove(:foo).add(["baz", "count"]) { |val| "#{val}!"}
    expect(tag_formatter.format(tags)).to eq({"foo" => "bar", "baz" => "boo!", "count" => "1!"})

    tag_formatter.remove(:foo).add("foo", :inspect)
    expect(tag_formatter.format(tags)).to eq({"foo" => '"bar"', "baz" => "boo!", "count" => "1!"})
  end

  it "should be able to clear all formatters" do
    tag_formatter = Lumberjack::TagFormatter.new.default(&:to_s).add(:foo, &:reverse)
    expect(tag_formatter.format(tags)).to eq({"foo" => "rab", "baz" => "boo", "count" => "1"})
    tag_formatter.clear
    expect(tag_formatter.format(tags)).to eq tags
  end

  it "should return the tags themselves if not formatting is necessary" do
    tag_formatter = Lumberjack::TagFormatter.new.add(:other, &:reverse)
    expect(tag_formatter.format(tags).object_id).to eq tags.object_id
  end

end
