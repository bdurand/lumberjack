# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack do
  describe "VERSION" do
    it "is defined" do
      expect(Lumberjack::VERSION).not_to be_nil
    end
  end

  describe "#context" do
    it "should create a context with attributes for a block" do
      Lumberjack.context do
        Lumberjack.tag(foo: "bar")
        expect(Lumberjack.context_attributes).to eq({"foo" => "bar"})
      end
    end

    it "should determine if it is inside a context block" do
      expect(Lumberjack.in_context?).to eq false
      Lumberjack.context do
        expect(Lumberjack.in_context?).to eq true
      end
      expect(Lumberjack.in_context?).to eq false
    end

    it "should return the result of the context block" do
      result = Lumberjack.context { :foo }
      expect(result).to eq :foo
    end
  end

  describe "#use_context" do
    it "should return the result of the use_context block" do
      result = Lumberjack.use_context(nil) { :foo }
      expect(result).to eq :foo
    end

    it "should create a context based on passed in context" do
      context = Lumberjack::Context.new
      context.assign_attributes(foo: "bar")
      Lumberjack.use_context(context) do
        expect(Lumberjack.context_attributes).to eq("foo" => "bar")
      end
    end
  end

  describe "#tag" do
    it "does nothing when called outside of a context block" do
      Lumberjack.tag(foo: "bar")
      expect(Lumberjack.context_attributes).to be_nil
    end

    it "sets attributes on the current context when called inside a context block" do
      Lumberjack.context do
        Lumberjack.tag(foo: "bar")
        expect(Lumberjack.context_attributes).to eq({"foo" => "bar"})
      end
    end

    it "sets attributes in a new context block" do
      expect(Lumberjack.context_attributes).to be_nil
      Lumberjack.tag(foo: "bar") do
        expect(Lumberjack.context_attributes).to eq({"foo" => "bar"})
      end
      expect(Lumberjack.context_attributes).to be_nil
    end

    it "returns the result of the block" do
      result = Lumberjack.tag(foo: "bar") { :foobar }
      expect(result).to eq :foobar
    end

    it "inherits attributes from the parent context" do
      Lumberjack.tag(bip: "bap") do
        Lumberjack.tag(foo: "bar")
        expect(Lumberjack.context_attributes).to eq({"foo" => "bar", "bip" => "bap"})
        Lumberjack.tag(baz: "boo") do
          expect(Lumberjack.context_attributes).to eq({"foo" => "bar", "bip" => "bap", "baz" => "boo"})
        end
        expect(Lumberjack.context_attributes).to eq({"foo" => "bar", "bip" => "bap"})
      end
      expect(Lumberjack.context_attributes).to be_nil
    end
  end

  it "can build a formatter" do
    formatter = Lumberjack.build_formatter do |config|
      config.add(Integer) { |i| i * 2 }
    end
    expect(formatter).to be_a(Lumberjack::EntryFormatter)
    expect(formatter.format(12, nil).first).to eq(24)
  end
end
