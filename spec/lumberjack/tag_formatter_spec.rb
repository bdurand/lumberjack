# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::TagFormatter do
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

  it "should be able to add tag name specific formatters" do
    formatter = Lumberjack::Formatter.new.clear.add(String, :inspect)
    tag_formatter = Lumberjack::TagFormatter.new.add(:foo, formatter)
    expect(tag_formatter.format(tags)).to eq({"foo" => '"bar"', "baz" => "boo", "count" => 1})

    tag_formatter.remove(:foo).add(["baz", "count"]) { |val| "#{val}!" }
    expect(tag_formatter.format(tags)).to eq({"foo" => "bar", "baz" => "boo!", "count" => "1!"})

    tag_formatter.remove(:foo).add("foo", :inspect)
    expect(tag_formatter.format(tags)).to eq({"foo" => '"bar"', "baz" => "boo!", "count" => "1!"})
  end

  it "should be able to add tag formatters with add_tag" do
    tag_formatter = Lumberjack::TagFormatter.new
    tag_formatter.add_tag("foo") { |val| {"bar" => val.to_s} }
    expect(tag_formatter.format({"foo" => 12})).to eq({"foo" => {"bar" => "12"}})
  end

  it "should be able to add class formatters" do
    tag_formatter = Lumberjack::TagFormatter.new.add(Integer) { |val| val * 2 }
    tag_formatter.add(String, :redact)
    expect(tag_formatter.format(tags)).to eq({"foo" => "*****", "baz" => "*****", "count" => 2})

    tag_formatter.remove(String)
    expect(tag_formatter.format(tags)).to eq({"foo" => "bar", "baz" => "boo", "count" => 2})
  end

  it "should be able to add class formatters by class name" do
    tag_formatter = Lumberjack::TagFormatter.new
    tag_formatter.add_class("String") { |val| val.reverse }
    expect(tag_formatter.format({"foo" => "bar", "baz" => "boo", "count" => 1})).to eq({"foo" => "rab", "baz" => "oob", "count" => 1})
  end

  it "should use a class formatter on child classes" do
    tag_formatter = Lumberjack::TagFormatter.new.add(Numeric) { |val| val * 2 }
    expect(tag_formatter.format({"foo" => 2.5, "bar" => 3})).to eq({"foo" => 5.0, "bar" => 6})
  end

  it "should use class formatters for modules" do
    tag_formatter = Lumberjack::TagFormatter.new.add(Enumerable) { |val| val.to_a.join(", ") }
    expect(tag_formatter.format({"foo" => [1, 2, 3], "bar" => "baz"})).to eq({"foo" => "1, 2, 3", "bar" => "baz"})
  end

  it "can mix and match tag and class formatters" do
    tag_formatter = Lumberjack::TagFormatter.new
    tag_formatter.add(:foo, &:reverse)
    tag_formatter.add(Integer, &:even?)
    expect(tag_formatter.format(tags)).to eq({"foo" => "rab", "baz" => "boo", "count" => false})
  end

  it "applies class formatters inside arrays and hashes" do
    tag_formatter = Lumberjack::TagFormatter.new
    tag_formatter.add(Integer, &:even?)
    tag_formatter.add(String, &:reverse)

    expect(tag_formatter.format({"foo" => [1, 2, 3], "bar" => {"baz" => "boo"}})).to eq({
      "foo" => [false, true, false],
      "bar" => {"baz" => "oob"}
    })
  end

  it "applies name formatters inside hashes using dot syntax" do
    tag_formatter = Lumberjack::TagFormatter.new
    tag_formatter.add("foo.bar", &:reverse)
    expect(tag_formatter.format({"foo" => {"bar" => "baz"}})).to eq({"foo" => {"bar" => "zab"}})
  end

  it "recursively applies class formatters to nested hashes" do
    tag_formatter = Lumberjack::TagFormatter.new
    tag_formatter.add("foo") { |val| {"bar" => val.to_s} }
    tag_formatter.add(String, &:reverse)
    expect(tag_formatter.format({"foo" => 12})).to eq({"foo" => {"bar" => "21"}})
  end

  it "recursively applies class formatters to nested arrays" do
    tag_formatter = Lumberjack::TagFormatter.new
    tag_formatter.add("foo") { |val| [val, val] }
    tag_formatter.add(String, &:reverse)
    expect(tag_formatter.format({"foo" => "bar"})).to eq({"foo" => ["rab", "rab"]})
  end

  it "short circuits recursive formatting for already formatted classes" do
    tag_formatter = Lumberjack::TagFormatter.new
    tag_formatter.add(String) { |val| "#{val},#{val}".split(",") }
    expect(tag_formatter.format({"foo" => "bar"})).to eq({"foo" => ["bar", "bar"]})
  end

  it "should be able to clear all formatters" do
    tag_formatter = Lumberjack::TagFormatter.new.default(&:to_s).add(:foo, &:reverse)
    expect(tag_formatter.format(tags)).to eq({"foo" => "rab", "baz" => "boo", "count" => "1"})
    tag_formatter.clear
    expect(tag_formatter.format(tags)).to eq tags
  end

  it "should return the tags themselves if not formatting is necessary" do
    tag_formatter = Lumberjack::TagFormatter.new
    expect(tag_formatter.format(tags).object_id).to eq tags.object_id
  end
end
