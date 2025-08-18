# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::TagFormatter do
  let(:attributes) { {"foo" => "bar", "baz" => "boo", "count" => 1} }

  it "should do nothing by default" do
    attribute_formatter = Lumberjack::TagFormatter.new
    expect(attribute_formatter.format(attributes)).to eq attributes
  end

  it "should have a default formatter as a Formatter" do
    formatter = Lumberjack::Formatter.new.clear.add(String, :inspect)
    attribute_formatter = Lumberjack::TagFormatter.new.default(formatter)
    expect(attribute_formatter.format(attributes)).to eq({"foo" => '"bar"', "baz" => '"boo"', "count" => 1})
  end

  it "should be able to add tag name specific formatters" do
    formatter = Lumberjack::Formatter.new.clear.add(String, :inspect)
    attribute_formatter = Lumberjack::TagFormatter.new.add(:foo, formatter)
    expect(attribute_formatter.format(attributes)).to eq({"foo" => '"bar"', "baz" => "boo", "count" => 1})

    attribute_formatter.remove(:foo).add(["baz", "count"]) { |val| "#{val}!" }
    expect(attribute_formatter.format(attributes)).to eq({"foo" => "bar", "baz" => "boo!", "count" => "1!"})

    attribute_formatter.remove(:foo).add("foo", :inspect)
    expect(attribute_formatter.format(attributes)).to eq({"foo" => '"bar"', "baz" => "boo!", "count" => "1!"})
  end

  it "should be able to add attribute formatters with add_attribute" do
    attribute_formatter = Lumberjack::TagFormatter.new
    attribute_formatter.add_attribute("foo") { |val| {"bar" => val.to_s} }
    expect(attribute_formatter.format({"foo" => 12})).to eq({"foo" => {"bar" => "12"}})
  end

  it "should be able to add class formatters" do
    attribute_formatter = Lumberjack::TagFormatter.new.add(Integer) { |val| val * 2 }
    attribute_formatter.add(String, :redact)
    expect(attribute_formatter.format(attributes)).to eq({"foo" => "*****", "baz" => "*****", "count" => 2})

    attribute_formatter.remove(String)
    expect(attribute_formatter.format(attributes)).to eq({"foo" => "bar", "baz" => "boo", "count" => 2})
  end

  it "should be able to add class formatters by class name" do
    attribute_formatter = Lumberjack::TagFormatter.new
    attribute_formatter.add_class("String") { |val| val.reverse }
    expect(attribute_formatter.format({"foo" => "bar", "baz" => "boo", "count" => 1})).to eq({"foo" => "rab", "baz" => "oob", "count" => 1})
  end

  it "should use a class formatter on child classes" do
    attribute_formatter = Lumberjack::TagFormatter.new.add(Numeric) { |val| val * 2 }
    expect(attribute_formatter.format({"foo" => 2.5, "bar" => 3})).to eq({"foo" => 5.0, "bar" => 6})
  end

  it "should use class formatters for modules" do
    attribute_formatter = Lumberjack::TagFormatter.new.add(Enumerable) { |val| val.to_a.join(", ") }
    expect(attribute_formatter.format({"foo" => [1, 2, 3], "bar" => "baz"})).to eq({"foo" => "1, 2, 3", "bar" => "baz"})
  end

  it "can mix and match tag and class formatters" do
    attribute_formatter = Lumberjack::TagFormatter.new
    attribute_formatter.add(:foo, &:reverse)
    attribute_formatter.add(Integer, &:even?)
    expect(attribute_formatter.format(attributes)).to eq({"foo" => "rab", "baz" => "boo", "count" => false})
  end

  it "applies class formatters inside arrays and hashes" do
    attribute_formatter = Lumberjack::TagFormatter.new
    attribute_formatter.add(Integer, &:even?)
    attribute_formatter.add(String, &:reverse)

    expect(attribute_formatter.format({"foo" => [1, 2, 3], "bar" => {"baz" => "boo"}})).to eq({
      "foo" => [false, true, false],
      "bar" => {"baz" => "oob"}
    })
  end

  it "applies name formatters inside hashes using dot syntax" do
    attribute_formatter = Lumberjack::TagFormatter.new
    attribute_formatter.add("foo.bar", &:reverse)
    expect(attribute_formatter.format({"foo" => {"bar" => "baz"}})).to eq({"foo" => {"bar" => "zab"}})
  end

  it "recursively applies class formatters to nested hashes" do
    attribute_formatter = Lumberjack::TagFormatter.new
    attribute_formatter.add("foo") { |val| {"bar" => val.to_s} }
    attribute_formatter.add(String, &:reverse)
    expect(attribute_formatter.format({"foo" => 12})).to eq({"foo" => {"bar" => "21"}})
  end

  it "recursively applies class formatters to nested arrays" do
    attribute_formatter = Lumberjack::TagFormatter.new
    attribute_formatter.add("foo") { |val| [val, val] }
    attribute_formatter.add(String, &:reverse)
    expect(attribute_formatter.format({"foo" => "bar"})).to eq({"foo" => ["rab", "rab"]})
  end

  it "short circuits recursive formatting for already formatted classes" do
    attribute_formatter = Lumberjack::TagFormatter.new
    attribute_formatter.add(String) { |val| "#{val},#{val}".split(",") }
    expect(attribute_formatter.format({"foo" => "bar"})).to eq({"foo" => ["bar", "bar"]})
  end

  it "should be able to clear all formatters" do
    attribute_formatter = Lumberjack::TagFormatter.new.default(&:to_s).add(:foo, &:reverse)
    expect(attribute_formatter.format(attributes)).to eq({"foo" => "rab", "baz" => "boo", "count" => "1"})
    attribute_formatter.clear
    expect(attribute_formatter.format(attributes)).to eq attributes
  end

  it "should return the attributes themselves if not formatting is necessary" do
    attribute_formatter = Lumberjack::TagFormatter.new
    expect(attribute_formatter.format(attributes).object_id).to eq attributes.object_id
  end
end
