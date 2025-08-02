require "spec_helper"

RSpec.describe Lumberjack::Context do
  describe "#tag" do
    it "should have tags" do
      context = Lumberjack::Context.new
      expect(context.tags).to eq({})
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
end
