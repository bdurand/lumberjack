# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::TagContext do
  let(:tags) { {} }
  let(:tag_context) { Lumberjack::TagContext.new(tags) }

  describe "#to_h" do
    it "returns a copy of the tags" do
      tags["a"] = 1
      hash = tag_context.to_h
      expect(hash).to eq({"a" => 1})
      expect(hash.object_id).not_to eq(tag_context.to_h.object_id)

      tags["b"] = 2
      expect(hash).to eq({"a" => 1})
    end
  end
  describe "#tag" do
    it "should have tags" do
      expect(tag_context.to_h).to eq({})
      tag_context.tag(foo: "bar", baz: "boo")
      expect(tag_context.to_h).to eq({"foo" => "bar", "baz" => "boo"})
      tag_context[:stuff] = "nonsense"
      expect(tag_context.to_h).to eq({"foo" => "bar", "baz" => "boo", "stuff" => "nonsense"})
      expect(tag_context[:stuff]).to eq("nonsense")
    end

    it "should flatten tags" do
      tag_context.tag(foo: {bar: "baz", far: "qux"})
      expect(tag_context.to_h).to eq({"foo.bar" => "baz", "foo.far" => "qux"})

      tag_context.tag("foo.bip" => "bop", "foo.far" => "foe") do
        expect(tag_context.to_h).to eq({"foo.bar" => "baz", "foo.bip" => "bop", "foo.far" => "foe"})
      end
    end
  end

  describe "#[]" do
    it "sets and gets a tag value" do
      tag_context[:foo] = "bar"
      expect(tag_context[:foo]).to eq("bar")
      expect(tag_context.to_h).to eq({"foo" => "bar"})
    end

    it "flattens nested tags" do
      tag_context[:foo] = {bar: "baz", far: "qux"}
      expect(tag_context.to_h).to eq({"foo.bar" => "baz", "foo.far" => "qux"})
    end

    it "returns a hash with subtags" do
      tag_context.tag(foo: {bar: "baz", far: "qux"})
      expect(tag_context[:foo]).to eq({"bar" => "baz", "far" => "qux"})
    end

    it "returns has deeply nested tags" do
      tag_context.tag(a: {b: {c: {d: 4, e: 5}, f: 6}, g: 7})
      expect(tag_context[:a]).to eq({"b.c.d" => 4, "b.c.e" => 5, "b.f" => 6, "g" => 7})
      expect(tag_context["a.b"]).to eq({"c.d" => 4, "c.e" => 5, "f" => 6})
    end
  end

  describe "#delete" do
    it "removes specified tags" do
      tag_context[:foo] = "bar"
      tag_context[:baz] = "boo"
      tag_context[:qux] = "quux"
      expect(tag_context.to_h).to eq({"foo" => "bar", "baz" => "boo", "qux" => "quux"})
      tag_context.delete(:foo, :baz)
      expect(tag_context.to_h).to eq({"qux" => "quux"})
    end

    it "removes subtags" do
      tag_context.tag(foo: {bar: "baz", far: "qux"})
      expect(tag_context.to_h).to eq({"foo.bar" => "baz", "foo.far" => "qux"})
      tag_context.delete(:foo)
      expect(tag_context.to_h).to eq({})
    end
  end
end
