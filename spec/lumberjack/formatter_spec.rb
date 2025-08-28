# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Formatter do
  let(:formatter) { Lumberjack::Formatter.default }

  describe "optimized formatters for primitive types" do
    let(:formatter) { Lumberjack::Formatter.new.add(Object, :inspect) }

    it "should have an optimized set of formatters that return self for primitive types" do
      expect(formatter.format("foo")).to eq("foo")
      expect(formatter.format(1)).to eq(1)
      expect(formatter.format(2.1)).to eq(2.1)
      expect(formatter.format(true)).to eq(true)
      expect(formatter.format(false)).to eq(false)
      expect(formatter.format(:foo)).to eq(":foo")
    end

    it "should be able to override the optimized formatters" do
      formatter.add(String) { |s| s.upcase }
      expect(formatter.format("foo")).to eq("FOO")
      expect(formatter.format(1)).to eq(1) # Still uses optimized formatter
    end
  end

  describe "#build" do
    it "builds a formatter in a block" do
      formatter = Lumberjack::Formatter.build do
        add(String) { |s| s.upcase }
        add(Integer) { |obj| "number: #{obj}" }
      end
      expect(formatter.format("foo")).to eq("FOO")
      expect(formatter.format(10)).to eq("number: 10")
    end
  end

  describe "#format" do
    it "should have a default set of formatters" do
      expect(formatter.format("abc")).to eq("abc")
      expect(formatter.format([1, 2, 3])).to eq([1, 2, 3])
      expect(formatter.format(ArgumentError.new("boom"))).to eq("ArgumentError: boom")
    end

    it "should be able to add a formatter object for a class" do
      formatter.add(Numeric, lambda { |obj| "number: #{obj}" })
      expect(formatter.format(10)).to eq("number: 10")
    end

    it "should be able to add a formatter object for a class name" do
      formatter.add("Numeric", lambda { |obj| "number: #{obj}" })
      expect(formatter.format(10)).to eq("number: 10")
    end

    it "should be able to add a formatter object for multiple classes" do
      formatter.add([Numeric, NilClass], &:to_i)
      expect(formatter.format(10.1)).to eq(10)
      expect(formatter.format(nil)).to eq(0)
    end

    it "should be able to add a formatter with arguments" do
      formatter.add(String, :truncate, 9)
      expect(formatter.format("1234567890")).to eq("12345678…")
    end

    it "should be able to add a formatter object for a module" do
      formatter.add(Enumerable, lambda { |obj| "list: #{obj.inspect}" })
      expect(formatter.format([1, 2])).to eq("list: [1, 2]")
    end

    it "should be able to add a formatter block for a class" do
      formatter.add(Numeric) { |obj| "number: #{obj}" }
      expect(formatter.format(10)).to eq("number: 10")
    end

    it "should be able to remove a formatter for a class" do
      formatter = Lumberjack::Formatter.new
      formatter.add(Symbol, :inspect)
      expect(formatter.format(:foo)).to eq(":foo")
      formatter.remove(Symbol)
      expect(formatter.format(:foo)).to eq(:foo)
    end

    it "should be able to remove a formatter for a class" do
      formatter = Lumberjack::Formatter.new
      formatter.add([Symbol, Array], :inspect)
      expect(formatter.format(:foo)).to eq(":foo")
      formatter.remove([Symbol, Array])
      expect(formatter.format(:foo)).to eq(:foo)
    end

    it "should be able to remove multiple formatters" do
      formatter = Lumberjack::Formatter.new
      formatter.add([Symbol, Array], :inspect)
      expect(formatter.format(:foo)).to eq(":foo")
      expect(formatter.format([1, 2, 3])).to eq([1, 2, 3].inspect)
      formatter.remove([Symbol, Array])
      expect(formatter.format(:foo)).to eq(:foo)
      expect(formatter.format([1, 2, 3])).to eq([1, 2, 3])
    end

    it "should be able to chain add and remove calls" do
      expect(formatter.remove(String)).to eq(formatter)
      expect(formatter.add(String, Lumberjack::Formatter::StringFormatter.new)).to eq(formatter)
    end

    it "should format an object based on the class hierarchy" do
      formatter.add(Numeric) { |obj| "number: #{obj}" }
      formatter.add(Integer) { |obj| "fixed number: #{obj}" }
      expect(formatter.format(10)).to eq("fixed number: 10")
      expect(formatter.format(10.1)).to eq("number: 10.1")
    end

    it "should have a default formatter" do
      expect(formatter.format(:test)).to eq(":test")
      formatter.remove(Object)
      expect(formatter.format(:test)).to eq(:test)
    end

    it "applies the to_log_format method if there is no registered formatter" do
      obj = TestToLogFormat.new("test")
      expect(formatter.format(obj)).to eq("LOG FORMAT: test")
    end

    it "overrides the to_log_format method if there is a registered formatter" do
      formatter.add(TestToLogFormat) { |obj| obj.value.upcase }
      obj = TestToLogFormat.new("test")
      expect(formatter.format(obj)).to eq("TEST")
    end

    it "does not override the to_log_format if the registered formatter is on a parent class" do
      formatter.add(:object) { |obj| "Object:#{obj.object_id}" }
      obj = TestToLogFormat.new("test")
      expect(formatter.format(obj)).to eq("LOG FORMAT: test")
    end

    describe "clear" do
      it "should clear all mappings" do
        expect(formatter.format(:test)).to eq(":test")
        formatter.clear
        expect(formatter.format(:test)).to eq(:test)
      end
    end
  end

  describe "empty" do
    it "should be able to get an empty formatter" do
      silence_deprecations do
        expect(Lumberjack::Formatter.empty.format(:test)).to eq(:test)
      end
    end
  end

  describe "#merge" do
    it "merges the formats from the formatter" do
      formatter_1 = Lumberjack::Formatter.new
      formatter_1.add(String) { |s| s.to_s.upcase }
      formatter_1.add(Float, :round, 1)

      formatter_2 = Lumberjack::Formatter.new
      formatter_2.add(String) { |s| s.to_s.downcase }
      formatter_2.add(Integer, :multiply, 2)

      expect(formatter_2.include(formatter_1)).to eq formatter_2

      expect(formatter_2.format("test")).to eq("TEST")
      expect(formatter_2.format(3.14)).to eq(3.1)
      expect(formatter_2.format(2)).to eq(4)
    end
  end
end
