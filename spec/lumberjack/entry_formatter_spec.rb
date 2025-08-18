# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::EntryFormatter do
  describe "building formatters" do
    it "starts with a default message formatter and no attribute formatter" do
      entry_formatter = Lumberjack::EntryFormatter.new
      expect(entry_formatter.message_formatter).to_not be_nil
      expect(entry_formatter.attribute_formatter).to be_nil
      obj = Object.new
      expect(entry_formatter.message_formatter.format(obj)).to eq(obj.inspect)
    end

    it "can add new message formatters in a chain" do
      entry_formatter = Lumberjack::EntryFormatter.new
      formatter = lambda {}
      expect(entry_formatter.add(Object, formatter)).to eq(entry_formatter)
      expect(entry_formatter.message_formatter.formatter_for(Object)).to eq(formatter)
    end

    it "can remove message formatters in a chain" do
      entry_formatter = Lumberjack::EntryFormatter.new
      formatter = lambda {}
      entry_formatter.add(Object, formatter)
      expect(entry_formatter.remove(Object)).to eq(entry_formatter)
      expect(entry_formatter.message_formatter.formatter_for(Object)).to be_nil
    end

    it "can add new attribute formatters in a chain" do
      entry_formatter = Lumberjack::EntryFormatter.new
      formatter = lambda {}
      expect(entry_formatter.attributes { add(Object, formatter) }).to eq(entry_formatter)
      expect(entry_formatter.attribute_formatter).to_not be_empty
    end

    it "can remove attribute formatters in a chain" do
      entry_formatter = Lumberjack::EntryFormatter.new
      formatter = lambda {}
      entry_formatter.attributes { add(Object, formatter) }
      expect(entry_formatter.attributes { remove(Object) }).to eq(entry_formatter)
      expect(entry_formatter.attribute_formatter).to be_empty
    end

    it "build a formatter with a build block" do
      entry_formatter = Lumberjack::EntryFormatter.build do
        add(String) { |obj| obj.to_s.upcase }
        attributes do
          add("status") { |obj| "[#{obj}]" }
        end
      end

      expect(entry_formatter.message_formatter.format("foobar")).to eq("FOOBAR")
      expect(entry_formatter.attribute_formatter.format("status" => "new")).to eq({"status" => "[new]"})
    end
  end

  describe "#entry" do
    let(:entry_formatter) { Lumberjack::EntryFormatter.new }

    it "does nothing with no message or attribute formatter" do
      entry_formatter.message_formatter = nil
      entry_formatter.attribute_formatter = nil
      message, attributes = entry_formatter.format("foobar", {"foo" => "bar"})
      expect(message).to eq("foobar")
      expect(attributes).to eq({"foo" => "bar"})
    end

    it "formats the message on the entry" do
      entry_formatter.add(String) { |obj| "String: #{obj}" }
      message, _ = entry_formatter.format("foobar", {"foo" => "bar"})
      expect(message).to eq("String: foobar")
    end

    it "calls the message block if it is a Proc" do
      message, _ = entry_formatter.format(-> { "foobar" }, {"foo" => "bar"})
      expect(message).to eq("foobar")
    end

    it "splits the message and attributes if the message formatter is a attributeged message" do
      entry_formatter.add(String) { |obj| Lumberjack::Formatter::TaggedMessage.new("attributeged: #{obj}", {"attribute" => obj}) }
      message, attributes = entry_formatter.format("foobar", {"foo" => "bar"})
      expect(message).to eq("attributeged: foobar")
      expect(attributes).to eq({"attribute" => "foobar", "foo" => "bar"})
    end

    it "applies the to_log_format method instead of the registered formatter if it exists" do
      obj = +"FooBar"
      def obj.to_log_format
        "Custom format for #{self}"
      end

      entry_formatter.add(String) { |s| "String: #{s}" }
      message, _ = entry_formatter.format("foobar", {})
      expect(message).to eq("String: foobar")

      message, _ = entry_formatter.format(obj, {})
      expect(message).to eq("Custom format for FooBar")
    end

    it "applies the attribute formatter to the attributes" do
      entry_formatter.attributes { add("foo") { |obj| "Foo: #{obj}" } }
      message, attributes = entry_formatter.format("foobar", {"foo" => "bar"})
      expect(message).to eq("foobar")
      expect(attributes).to eq({"foo" => "Foo: bar"})
    end

    it "calls Proc values in attributes" do
      message, attributes = entry_formatter.format("foobar", {"foo" => -> { "bar" }})
      expect(message).to eq("foobar")
      expect(attributes).to eq({"foo" => "bar"})
    end

    it "handles nil messages" do
      entry_formatter.message_formatter.clear
      message, attributes = entry_formatter.format(nil, {"foo" => "bar"})
      expect(message).to be_nil
      expect(attributes).to eq({"foo" => "bar"})
    end

    it "handles nil attributes" do
      entry_formatter.attributes { add("foo") { |obj| "Foo: #{obj}" } }
      message, attributes = entry_formatter.format("foobar", nil)
      expect(message).to eq("foobar")
      expect(attributes).to be_nil
    end
  end
end
