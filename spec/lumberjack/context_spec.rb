require "spec_helper"

RSpec.describe Lumberjack::Context do
  describe "#level" do
    it "should have a level" do
      context = Lumberjack::Context.new
      expect(context.level).to be_nil
      context.level = :info
      expect(context.level).to eq(Logger::INFO)
      context.level = nil
      expect(context.level).to be_nil
    end

    it "should inherit the parent context's level" do
      parent = Lumberjack::Context.new
      parent.level = Logger::WARN
      context = Lumberjack::Context.new(parent)
      expect(context.level).to eq(Logger::WARN)
    end
  end

  describe "#progname" do
    it "should have a progname" do
      context = Lumberjack::Context.new
      expect(context.progname).to be_nil
      context.progname = :test
      expect(context.progname).to eq("test")
      context.progname = nil
      expect(context.progname).to be_nil
    end

    it "should inherit the parent context's progname" do
      parent = Lumberjack::Context.new
      parent.progname = "parent"
      context = Lumberjack::Context.new(parent)
      expect(context.progname).to eq("parent")
    end
  end

  describe "#default_severity" do
    it "should have a default severity" do
      context = Lumberjack::Context.new
      expect(context.default_severity).to be_nil
      context.default_severity = :info
      expect(context.default_severity).to eq(Logger::INFO)
      context.default_severity = nil
      expect(context.default_severity).to be_nil
    end
  end

  describe "#assign_attributes" do
    it "should have attributes" do
      context = Lumberjack::Context.new
      expect(context.attributes).to be_nil
      context.assign_attributes(foo: "bar", baz: "boo")
      expect(context.attributes).to eq({"foo" => "bar", "baz" => "boo"})
      context[:stuff] = "nonsense"
      expect(context.attributes).to eq({"foo" => "bar", "baz" => "boo", "stuff" => "nonsense"})
      expect(context[:stuff]).to eq("nonsense")
    end

    it "should inherit attributes from a parent context" do
      parent = Lumberjack::Context.new
      parent.assign_attributes(foo: "bar", baz: "boo")
      context = Lumberjack::Context.new(parent)
      context.assign_attributes(foo: "other", stuff: "nonsense")
      expect(context.attributes).to eq({"foo" => "other", "baz" => "boo", "stuff" => "nonsense"})
      expect(parent.attributes).to eq({"foo" => "bar", "baz" => "boo"})
    end

    it "should flatten attributes" do
      context = Lumberjack::Context.new
      context.assign_attributes(foo: {bar: "baz", far: "qux"})
      expect(context.attributes).to eq({"foo.bar" => "baz", "foo.far" => "qux"})

      context.assign_attributes("foo.bip" => "bop", "foo.far" => "foe")
      expect(context.attributes).to eq({"foo.bar" => "baz", "foo.bip" => "bop", "foo.far" => "foe"})
    end
  end

  describe "#[]" do
    it "sets and gets an attribute value" do
      context = Lumberjack::Context.new
      context[:foo] = "bar"
      expect(context[:foo]).to eq("bar")
      expect(context.attributes).to eq({"foo" => "bar"})
    end

    it "flattens nested attributes" do
      context = Lumberjack::Context.new
      context[:foo] = {bar: "baz", far: "qux"}
      expect(context.attributes).to eq({"foo.bar" => "baz", "foo.far" => "qux"})
    end
  end

  describe "#delete" do
    it "removes specified attributes" do
      context = Lumberjack::Context.new
      context[:foo] = "bar"
      context[:baz] = "boo"
      context[:qux] = "quux"
      expect(context.attributes).to eq({"foo" => "bar", "baz" => "boo", "qux" => "quux"})
      context.delete(:foo, :baz)
      expect(context.attributes).to eq({"qux" => "quux"})
    end
  end

  describe "#reset" do
    it "clears all attributes and context data" do
      context = Lumberjack::Context.new
      context.assign_attributes(foo: "bar", baz: "boo")
      context.level = :info
      context.progname = "test"
      context.reset
      expect(context.attributes).to eq({})
      expect(context.level).to be_nil
      expect(context.progname).to be_nil
    end
  end
end
