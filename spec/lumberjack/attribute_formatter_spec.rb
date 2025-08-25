# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::AttributeFormatter do
  let(:attributes) { {"foo" => "bar", "baz" => "boo", "count" => 1} }

  describe "#build" do
    it "builds an attribute formatter in a block" do
      attribute_formatter = Lumberjack::AttributeFormatter.build do
        add(:foo) { |val| val.to_s.upcase }
      end
      expect(attribute_formatter.format(attributes)).to eq({"foo" => "BAR", "baz" => "boo", "count" => 1})
    end
  end

  describe "#format" do
    it "should do nothing by default" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      expect(attribute_formatter.format(attributes)).to eq attributes
    end

    it "should have a default formatter as a Formatter" do
      formatter = Lumberjack::Formatter.new.clear.add(String, :inspect)
      attribute_formatter = Lumberjack::AttributeFormatter.new.default(formatter)
      expect(attribute_formatter.format(attributes)).to eq({"foo" => '"bar"', "baz" => '"boo"', "count" => 1})
    end

    it "should be able to add tag name specific formatters" do
      formatter = Lumberjack::Formatter.new.clear.add(String, :inspect)
      attribute_formatter = Lumberjack::AttributeFormatter.new.add(:foo, formatter)
      expect(attribute_formatter.format(attributes)).to eq({"foo" => '"bar"', "baz" => "boo", "count" => 1})

      attribute_formatter.remove(:foo).add(["baz", "count"]) { |val| "#{val}!" }
      expect(attribute_formatter.format(attributes)).to eq({"foo" => "bar", "baz" => "boo!", "count" => "1!"})

      attribute_formatter.remove(:foo).add("foo", :inspect)
      expect(attribute_formatter.format(attributes)).to eq({"foo" => '"bar"', "baz" => "boo!", "count" => "1!"})
    end

    it "should be able to add attribute formatters with add_attribute" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      attribute_formatter.add_attribute("foo") { |val| val * 2 }
      expect(attribute_formatter.format({"foo" => 12})).to eq({"foo" => 24})
    end

    it "should be able to add class formatters" do
      attribute_formatter = Lumberjack::AttributeFormatter.new.add(Integer) { |val| val * 2 }
      attribute_formatter.add(String, :redact)
      expect(attribute_formatter.format(attributes)).to eq({"foo" => "*****", "baz" => "*****", "count" => 2})

      attribute_formatter.remove(String)
      expect(attribute_formatter.format(attributes)).to eq({"foo" => "bar", "baz" => "boo", "count" => 2})
    end

    it "should be able to add class formatters by class name" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      attribute_formatter.add_class("String") { |val| val.reverse }
      expect(attribute_formatter.format({"foo" => "bar", "baz" => "boo", "count" => 1})).to eq({"foo" => "rab", "baz" => "oob", "count" => 1})
    end

    it "should use a class formatter on child classes" do
      attribute_formatter = Lumberjack::AttributeFormatter.new.add(Numeric) { |val| val * 2 }
      expect(attribute_formatter.format({"foo" => 2.5, "bar" => 3})).to eq({"foo" => 5.0, "bar" => 6})
    end

    it "should use class formatters for modules" do
      attribute_formatter = Lumberjack::AttributeFormatter.new.add(Enumerable) { |val| val.to_a.join(", ") }
      expect(attribute_formatter.format({"foo" => [1, 2, 3], "bar" => "baz"})).to eq({"foo" => "1, 2, 3", "bar" => "baz"})
    end

    it "can mix and match tag and class formatters" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      attribute_formatter.add(:foo, &:reverse)
      attribute_formatter.add(Integer, &:even?)
      expect(attribute_formatter.format(attributes)).to eq({"foo" => "rab", "baz" => "boo", "count" => false})
    end

    it "applies class formatters inside arrays and hashes" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      attribute_formatter.add(Integer, &:even?)
      attribute_formatter.add(String, &:reverse)

      expect(attribute_formatter.format({"foo" => [1, 2, 3], "bar" => {"baz" => "boo"}})).to eq({
        "foo" => [false, true, false],
        "bar" => {"baz" => "oob"}
      })
    end

    it "applies name formatters inside hashes using dot syntax" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      attribute_formatter.add("foo.bar", &:reverse)
      expect(attribute_formatter.format({"foo" => {"bar" => "baz"}})).to eq({"foo" => {"bar" => "zab"}})
    end

    it "recursively applies class formatters to nested hashes" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      attribute_formatter.add("foo") { |val| {"bar" => val.to_s} }
      attribute_formatter.add(String, &:reverse)
      expect(attribute_formatter.format({"foo" => 12})).to eq({"foo" => {"bar" => "21"}})
    end

    it "recursively applies class formatters to nested arrays" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      attribute_formatter.add("foo") { |val| [val, val] }
      attribute_formatter.add(String, &:reverse)
      expect(attribute_formatter.format({"foo" => "bar"})).to eq({"foo" => ["rab", "rab"]})
    end

    it "short circuits recursive formatting for already formatted classes" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      attribute_formatter.add(String) { |val| "#{val},#{val}".split(",") }
      expect(attribute_formatter.format({"foo" => "bar"})).to eq({"foo" => ["bar", "bar"]})
    end

    it "should be able to clear all formatters" do
      attribute_formatter = Lumberjack::AttributeFormatter.new.default(&:to_s).add(:foo, &:reverse)
      expect(attribute_formatter.format(attributes)).to eq({"foo" => "rab", "baz" => "boo", "count" => "1"})
      attribute_formatter.clear
      expect(attribute_formatter.format(attributes)).to eq attributes
    end

    it "should return the attributes themselves if not formatting is necessary" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      expect(attribute_formatter.format(attributes).object_id).to eq attributes.object_id
    end

    it "uses the attributes from a TaggedMessage" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      attribute_formatter.add("foo") { |val| Lumberjack::Formatter::TaggedMessage.new(val.upcase, "attr" => val) }
      expect(attribute_formatter.format({"foo" => "bar"})).to eq({"foo" => {"attr" => "bar"}})
    end
  end

  describe "#formatter_for" do
    let(:formatter) do
      Lumberjack::AttributeFormatter.build do
        add(:upcase) { |val| val.to_s.upcase }
        add(:downcase) { |val| val.to_s.downcase }
        add(Array) { |val| val.join(", ") }
      end
    end

    it "gets a formatter for an attribute name" do
      expect(formatter.formatter_for(:upcase).call("Foo")).to eq("FOO")
      expect(formatter.formatter_for(:downcase).call("Foo")).to eq("foo")
      expect(formatter.formatter_for(:other)).to be_nil
    end
  end
end
