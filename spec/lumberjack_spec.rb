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

  describe "#ensure_context" do
    it "should create a context if one does not exist" do
      expect(Lumberjack.in_context?).to eq false
      value = Lumberjack.ensure_context do
        expect(Lumberjack.in_context?).to eq true
        :foo
      end
      expect(Lumberjack.in_context?).to eq false
      expect(value).to eq :foo
    end

    it "does not create a new context if one already exists" do
      Lumberjack.context do
        value = Lumberjack.ensure_context do
          Lumberjack.tag(baz: "bap")
          :foo
        end
        expect(Lumberjack.context_attributes).to eq({"baz" => "bap"})
        expect(value).to eq :foo
      end
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

  describe "#isolation_level" do
    around do |example|
      original_level = Lumberjack.isolation_level
      begin
        example.run
      ensure
        Lumberjack.isolation_level = original_level
      end
    end

    it "defaults to :fiber" do
      expect(Lumberjack.isolation_level).to eq :fiber
    end

    it "isolates the global context by fiber when set to :fiber" do
      Lumberjack.isolation_level = :fiber
      Lumberjack.context do
        fiber = Fiber.new do
          expect(Lumberjack.in_context?).to be false
        end
        fiber.resume
        expect(Lumberjack.in_context?).to be true
      end
    end

    it "isolates the global context by thread when set to :thread" do
      Lumberjack.isolation_level = :thread
      Lumberjack.context do
        thread = Thread.new do
          expect(Lumberjack.in_context?).to be false
        end
        fiber = Fiber.new do
          expect(Lumberjack.in_context?).to be true
        end
        fiber.resume
        thread.join
        expect(Lumberjack.in_context?).to be true
      end
    end

    it "is inherited by loggers" do
      expect(Lumberjack::Logger.new(:test).isolation_level).to eq :fiber
      Lumberjack.isolation_level = :thread
      expect(Lumberjack::Logger.new(:test).isolation_level).to eq :thread
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
    entry_formatter = Lumberjack.build_formatter do |formatter|
      formatter.format_class(Integer) { |i| i * 2 }
    end
    expect(entry_formatter).to be_a(Lumberjack::EntryFormatter)
    expect(entry_formatter.format(12, nil).first).to eq(24)
  end
end
