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

  describe "#tag" do
    it "should have tags" do
      context = Lumberjack::Context.new
      expect(context.tags).to be_nil
      context.tag(foo: "bar", baz: "boo")
      expect(context.tags).to eq({"foo" => "bar", "baz" => "boo"})
      context[:stuff] = "nonsense"
      expect(context.tags).to eq({"foo" => "bar", "baz" => "boo", "stuff" => "nonsense"})
      expect(context[:stuff]).to eq("nonsense")
    end

    it "should inherit tags from a parent context" do
      parent = Lumberjack::Context.new
      parent.tag(foo: "bar", baz: "boo")
      context = Lumberjack::Context.new(parent)
      context.tag(foo: "other", stuff: "nonsense")
      expect(context.tags).to eq({"foo" => "other", "baz" => "boo", "stuff" => "nonsense"})
      expect(parent.tags).to eq({"foo" => "bar", "baz" => "boo"})
    end

    it "should flatten tags" do
      context = Lumberjack::Context.new
      context.tag(foo: {bar: "baz", far: "qux"})
      expect(context.tags).to eq({"foo.bar" => "baz", "foo.far" => "qux"})

      context.tag("foo.bip" => "bop", "foo.far" => "foe") do
        expect(context.tags).to eq({"foo.bar" => "baz", "foo.bip" => "bop", "foo.far" => "foe"})
      end
    end
  end

  describe "#[]" do
    it "sets and gets a tag value" do
      context = Lumberjack::Context.new
      context[:foo] = "bar"
      expect(context[:foo]).to eq("bar")
      expect(context.tags).to eq({"foo" => "bar"})
    end

    it "flattens nested tags" do
      context = Lumberjack::Context.new
      context[:foo] = {bar: "baz", far: "qux"}
      expect(context.tags).to eq({"foo.bar" => "baz", "foo.far" => "qux"})
    end
  end

  describe "#delete" do
    it "removes specified tags" do
      context = Lumberjack::Context.new
      context[:foo] = "bar"
      context[:baz] = "boo"
      context[:qux] = "quux"
      expect(context.tags).to eq({"foo" => "bar", "baz" => "boo", "qux" => "quux"})
      context.delete(:foo, :baz)
      expect(context.tags).to eq({"qux" => "quux"})
    end
  end

  describe "#reset" do
    it "clears all tags and context data" do
      context = Lumberjack::Context.new
      context.tag(foo: "bar", baz: "boo")
      context.level = :info
      context.progname = "test"
      context.reset
      expect(context.tags).to eq({})
      expect(context.level).to be_nil
      expect(context.progname).to be_nil
    end
  end
end
