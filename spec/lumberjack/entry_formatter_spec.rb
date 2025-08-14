# frozen_string_literal: true

require "spec_helper"

describe Lumberjack::EntryFormatter do
  describe "building formatters" do
    it "starts with a default message formatter and no tag formatter" do
      entry_formatter = Lumberjack::EntryFormatter.new
      expect(entry_formatter.message_formatter).to_not be_nil
      expect(entry_formatter.tag_formatter).to be_nil
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

    it "can add new tag formatters in a chain" do
      entry_formatter = Lumberjack::EntryFormatter.new
      formatter = lambda {}
      expect(entry_formatter.tags { add(Object, formatter) }).to eq(entry_formatter)
      expect(entry_formatter.tag_formatter).to_not be_empty
    end

    it "can remove tag formatters in a chain" do
      entry_formatter = Lumberjack::EntryFormatter.new
      formatter = lambda {}
      entry_formatter.tags { add(Object, formatter) }
      expect(entry_formatter.tags { remove(Object) }).to eq(entry_formatter)
      expect(entry_formatter.tag_formatter).to be_empty
    end
  end

  describe "#entry" do
    let(:entry_formatter) { Lumberjack::EntryFormatter.new }

    it "does nothing with no message or tag formatter" do
      entry_formatter.message_formatter = nil
      entry_formatter.tag_formatter = nil
      message, tags = entry_formatter.format("foobar", {"foo" => "bar"})
      expect(message).to eq("foobar")
      expect(tags).to eq({"foo" => "bar"})
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

    it "splits the message and tags if the message formatter is a tagged message" do
      entry_formatter.add(String) { |obj| Lumberjack::Formatter::TaggedMessage.new("Tagged: #{obj}", {"tag" => obj}) }
      message, tags = entry_formatter.format("foobar", {"foo" => "bar"})
      expect(message).to eq("Tagged: foobar")
      expect(tags).to eq({"tag" => "foobar", "foo" => "bar"})
    end

    it "applies the tag formatter to the tags" do
      entry_formatter.tags { add("foo") { |obj| "Foo: #{obj}" } }
      message, tags = entry_formatter.format("foobar", {"foo" => "bar"})
      expect(message).to eq("foobar")
      expect(tags).to eq({"foo" => "Foo: bar"})
    end

    it "calls Proc values in tags" do
      message, tags = entry_formatter.format("foobar", {"foo" => -> { "bar" }})
      expect(message).to eq("foobar")
      expect(tags).to eq({"foo" => "bar"})
    end

    it "handles nil messages" do
      entry_formatter.message_formatter.clear
      message, tags = entry_formatter.format(nil, {"foo" => "bar"})
      expect(message).to be_nil
      expect(tags).to eq({"foo" => "bar"})
    end

    it "handles nil tags" do
      entry_formatter.tags { add("foo") { |obj| "Foo: #{obj}" } }
      message, tags = entry_formatter.format("foobar", nil)
      expect(message).to eq("foobar")
      expect(tags).to be_nil
    end
  end
end
