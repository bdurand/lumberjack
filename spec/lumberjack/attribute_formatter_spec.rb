# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::AttributeFormatter do
  let(:attributes) { {"foo" => "bar", "baz" => "boo", "count" => 1} }

  describe "#build" do
    it "builds an attribute formatter in a block" do
      attribute_formatter = Lumberjack::AttributeFormatter.build do |config|
        config.add_attribute(:foo) { |val| val.to_s.upcase }
      end
      expect(attribute_formatter.format(attributes)).to eq({"foo" => "BAR", "baz" => "boo", "count" => 1})
    end
  end

  describe "#add", deprecation_mode: :silent do
    it "adds an attribute formatter for a specific attribute" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      attribute_formatter.add(:foo) { |val| val.to_s.upcase }
      expect(attribute_formatter.format(foo: "bar")).to eq({"foo" => "BAR"})
    end

    it "adds an attribute for a class" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      attribute_formatter.add(String) { |val| val.to_s.upcase }
      expect(attribute_formatter.format(foo: "bar")).to eq({"foo" => "BAR"})
    end
  end

  describe "#remove", deprecation_mode: :silent do
    it "removes an attribute formatter for a specific attribute" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      attribute_formatter.add(:foo) { |val| val.to_s.upcase }
      expect(attribute_formatter.format(foo: "bar")).to eq({"foo" => "BAR"})
      attribute_formatter.remove(:foo)
      expect(attribute_formatter.format(foo: "bar")).to eq({foo: "bar"})
    end

    it "removes an attribute formatter for a class" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      attribute_formatter.add(String) { |val| val.to_s.upcase }
      expect(attribute_formatter.format(foo: "bar")).to eq({"foo" => "BAR"})
      attribute_formatter.remove(String)
      expect(attribute_formatter.format(foo: "bar")).to eq({foo: "bar"})
    end
  end

  describe "#format" do
    it "should do nothing by default" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      expect(attribute_formatter.format(attributes)).to eq attributes
    end

    it "should have a default formatter as a Formatter" do
      formatter = Lumberjack::Formatter.new.add(String, :inspect)
      attribute_formatter = Lumberjack::AttributeFormatter.new.default(formatter)
      expect(attribute_formatter.format(attributes)).to eq({"foo" => '"bar"', "baz" => '"boo"', "count" => 1})
    end

    it "should be able to add tag name specific formatters" do
      formatter = Lumberjack::Formatter.new.clear.add(String, :inspect)
      attribute_formatter = Lumberjack::AttributeFormatter.new.add_attribute(:foo, formatter)
      expect(attribute_formatter.format(attributes)).to eq({"foo" => '"bar"', "baz" => "boo", "count" => 1})

      attribute_formatter.remove_attribute(:foo).add_attribute(["baz", "count"]) { |val| "#{val}!" }
      expect(attribute_formatter.format(attributes)).to eq({"foo" => "bar", "baz" => "boo!", "count" => "1!"})

      attribute_formatter.remove_attribute(:foo).add_attribute("foo", :inspect)
      expect(attribute_formatter.format(attributes)).to eq({"foo" => '"bar"', "baz" => "boo!", "count" => "1!"})
    end

    it "should be able to add attribute formatters with add_attribute" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      attribute_formatter.add_attribute("foo") { |val| val * 2 }
      expect(attribute_formatter.format({"foo" => 12})).to eq({"foo" => 24})
    end

    it "should be able to add and remove class formatters" do
      attribute_formatter = Lumberjack::AttributeFormatter.new.add_class(Integer) { |val| val * 2 }
      attribute_formatter.add_class(String, :redact)
      expect(attribute_formatter.format(attributes)).to eq({"foo" => "*****", "baz" => "*****", "count" => 2})

      attribute_formatter.remove_class(String)
      expect(attribute_formatter.format(attributes)).to eq({"foo" => "bar", "baz" => "boo", "count" => 2})
    end

    it "should be able to add class formatters by class name" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      attribute_formatter.add_class("String") { |val| val.reverse }
      expect(attribute_formatter.format({"foo" => "bar", "baz" => "boo", "count" => 1})).to eq({"foo" => "rab", "baz" => "oob", "count" => 1})
    end

    it "should use a class formatter on child classes" do
      attribute_formatter = Lumberjack::AttributeFormatter.new.add_class(Numeric) { |val| val * 2 }
      expect(attribute_formatter.format({"foo" => 2.5, "bar" => 3})).to eq({"foo" => 5.0, "bar" => 6})
    end

    it "should use class formatters for modules" do
      attribute_formatter = Lumberjack::AttributeFormatter.new.add_class(Enumerable) { |val| val.to_a.join(", ") }
      expect(attribute_formatter.format({"foo" => [1, 2, 3], "bar" => "baz"})).to eq({"foo" => "1, 2, 3", "bar" => "baz"})
    end

    it "can mix and match tag and class formatters" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      attribute_formatter.add_attribute(:foo, &:reverse)
      attribute_formatter.add_class(Integer, &:even?)
      expect(attribute_formatter.format(attributes)).to eq({"foo" => "rab", "baz" => "boo", "count" => false})
    end

    it "applies class formatters inside arrays and hashes" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      attribute_formatter.add_class(Integer, &:even?)
      attribute_formatter.add_class(String, &:reverse)

      expect(attribute_formatter.format({"foo" => [1, 2, 3], "bar" => {"baz" => "boo"}})).to eq({
        "foo" => [false, true, false],
        "bar" => {"baz" => "oob"}
      })
    end

    it "can pass arguments to class formatters" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      attribute_formatter.add_class(String, :truncate, 3)
      attribute_formatter.add_attribute(:foo, :truncate, 4)
      expect(attribute_formatter.format({"foo" => "foobar", "bar" => "bazqux"})).to eq({"foo" => "foo…", "bar" => "ba…"})
    end

    it "applies name formatters inside hashes using dot syntax" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      attribute_formatter.add_attribute("foo.bar", &:reverse)
      expect(attribute_formatter.format({"foo" => {"bar" => "baz"}})).to eq({"foo" => {"bar" => "zab"}})
    end

    it "recursively applies class formatters to nested hashes" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      attribute_formatter.add_attribute("foo") { |val| {"bar" => val.to_s} }
      attribute_formatter.add_class(String, &:reverse)
      expect(attribute_formatter.format({"foo" => 12})).to eq({"foo" => {"bar" => "21"}})
    end

    it "recursively applies class formatters to nested arrays" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      attribute_formatter.add_attribute("foo") { |val| [val, val] }
      attribute_formatter.add_class(String, &:reverse)
      expect(attribute_formatter.format({"foo" => "bar"})).to eq({"foo" => ["rab", "rab"]})
    end

    it "short circuits recursive formatting for already formatted classes" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      attribute_formatter.add_class(String) { |val| "#{val},#{val}".split(",") }
      expect(attribute_formatter.format({"foo" => "bar"})).to eq({"foo" => ["bar", "bar"]})
    end

    it "should be able to clear all formatters" do
      attribute_formatter = Lumberjack::AttributeFormatter.new.default(&:to_s).add_attribute(:foo, &:reverse)
      expect(attribute_formatter.format(attributes)).to eq({"foo" => "rab", "baz" => "boo", "count" => "1"})
      attribute_formatter.clear
      expect(attribute_formatter.format(attributes)).to eq attributes
    end

    it "should return the attributes themselves if not formatting is necessary" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      expect(attribute_formatter.format(attributes).object_id).to eq attributes.object_id
    end

    it "uses the attributes from a MessageAttributes" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      attribute_formatter.add_attribute("foo") { |val| Lumberjack::MessageAttributes.new(val.upcase, "attr" => val) }
      expect(attribute_formatter.format({"foo" => "bar"})).to eq({"foo" => {"attr" => "bar"}})
    end

    it "remaps attributes if the value is a Lumberjack::RemapAttribute instance" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      attribute_formatter.add_attribute("duration_ms") { |value| Lumberjack::RemapAttribute.new(duration: value.to_f / 1000) }
      expect(attribute_formatter.format({"duration_ms" => 1500})).to eq({"duration" => 1.5})
    end

    it "remaps structured attributes correctly" do
      attribute_formatter = Lumberjack::AttributeFormatter.new
      attribute_formatter.add_attribute(:email) { |value| Lumberjack::RemapAttribute.new(user: {email: value}) }
      attributes = {"user.id" => 42, "email" => "user@example.com"}
      expect(attribute_formatter.format(attributes)).to eq({"user.id" => 42, "user.email" => "user@example.com"})
    end

    it "returns an error string if there was an error formatting the value" do
      save_stderr = $stderr
      begin
        $stderr = StringIO.new
        attribute_formatter = Lumberjack::AttributeFormatter.new
        attribute_formatter.add_class(String, lambda { |obj| raise "error" })
        expect(attribute_formatter.format(attributes)["foo"]).to eq("<Error formatting String: RuntimeError error>")
      ensure
        $stderr = save_stderr
      end
    end
  end

  describe "#include_class?" do
    it "returns true if a formatter exists for a specific class" do
      formatter = Lumberjack::AttributeFormatter.build do |config|
        config.add_class(Array, :inspect)
      end
      expect(formatter.include_class?(Array)).to be true
      expect(formatter.include_class?("Array")).to be true
      expect(formatter.include_class?(String)).to be false
    end
  end

  describe "#include_attribute?" do
    it "returns true if a formatter exists for a specific attribute" do
      formatter = Lumberjack::AttributeFormatter.build do |config|
        config.add_attribute(:foo, :inspect)
      end
      expect(formatter.include_attribute?(:foo)).to be true
      expect(formatter.include_attribute?("foo")).to be true
      expect(formatter.include_attribute?(:bar)).to be false
    end
  end

  describe "#formatter_for_class" do
    let(:formatter) do
      Lumberjack::AttributeFormatter.build do |config|
        config.add_class(Array, :inspect)
      end
    end

    it "returns the formatter for a specific class" do
      expect(formatter.formatter_for_class(Array)).to be_a(Lumberjack::Formatter::InspectFormatter)
      expect(formatter.formatter_for_class("Array")).to be_a(Lumberjack::Formatter::InspectFormatter)
      expect(formatter.formatter_for_class(String)).to be_nil
    end
  end

  describe "#formatter_for_attribute" do
    let(:formatter) do
      Lumberjack::AttributeFormatter.build do |config|
        config.add_attribute(:foo, :inspect)
      end
    end

    it "returns the formatter for a specific attribute" do
      expect(formatter.formatter_for_attribute(:foo)).to be_a(Lumberjack::Formatter::InspectFormatter)
      expect(formatter.formatter_for_attribute("foo")).to be_a(Lumberjack::Formatter::InspectFormatter)
      expect(formatter.formatter_for_attribute(:bar)).to be_nil
    end
  end

  describe "#include" do
    it "merges the formats from the formatter" do
      formatter_1 = Lumberjack::AttributeFormatter.new
      formatter_1.add_class(String) { |val| val.to_s.upcase }
      formatter_1.add_class(Float, :round, 1)
      formatter_1.add_attribute(:tags) { |val| val.join(", ") }

      formatter_2 = Lumberjack::AttributeFormatter.new
      formatter_2.add_class(String) { |val| val.to_s.downcase }
      formatter_2.add_attribute(:foo) { |val| val.to_s.downcase }

      expect(formatter_2.include(formatter_1)).to eq formatter_2

      expect(formatter_2.format("test" => "Test")).to eq("test" => "TEST")
      expect(formatter_2.format("pi" => 3.14)).to eq("pi" => 3.1)
      expect(formatter_2.format("tags" => ["foo", "bar"])).to eq("tags" => "foo, bar")
      expect(formatter_2.format("foo" => "FOO")).to eq("foo" => "foo")
    end
  end

  describe "#prepend" do
    it "prepends the formats from the formatter" do
      formatter_1 = Lumberjack::AttributeFormatter.new
      formatter_1.add_class(String) { |val| val.to_s.upcase }
      formatter_1.add_class(Float, :round, 1)
      formatter_1.add_attribute(:tags) { |val| val.join(", ") }

      formatter_2 = Lumberjack::AttributeFormatter.new
      formatter_2.add_class(String) { |val| val.to_s.downcase }
      formatter_2.add_attribute(:foo) { |val| val.to_s.downcase }

      expect(formatter_2.prepend(formatter_1)).to eq formatter_2

      expect(formatter_2.format("test" => "Test")).to eq("test" => "test")
      expect(formatter_2.format("pi" => 3.14)).to eq("pi" => 3.1)
      expect(formatter_2.format("tags" => ["foo", "bar"])).to eq("tags" => "foo, bar")
      expect(formatter_2.format("foo" => "FOO")).to eq("foo" => "foo")
    end
  end
end
