# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::TagContext do
  let(:attributes) { {} }
  let(:tag_context) { Lumberjack::TagContext.new(attributes) }

  describe "#to_h" do
    it "returns a copy of the attributes" do
      attributes["a"] = 1
      hash = tag_context.to_h
      expect(hash).to eq({"a" => 1})
      expect(hash.object_id).not_to eq(tag_context.to_h.object_id)

      attributes["b"] = 2
      expect(hash).to eq({"a" => 1})
    end
  end
  describe "#tag" do
    it "should have attributes" do
      expect(tag_context.to_h).to eq({})
      tag_context.update(foo: "bar", baz: "boo")
      expect(tag_context.to_h).to eq({"foo" => "bar", "baz" => "boo"})
      tag_context[:stuff] = "nonsense"
      expect(tag_context.to_h).to eq({"foo" => "bar", "baz" => "boo", "stuff" => "nonsense"})
      expect(tag_context[:stuff]).to eq("nonsense")
    end

    it "should flatten attributes" do
      tag_context.update(foo: {bar: "baz", far: "qux"})
      expect(tag_context.to_h).to eq({"foo.bar" => "baz", "foo.far" => "qux"})

      tag_context.update("foo.bip" => "bop", "foo.far" => "foe") do
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

    it "flattens nested attributes" do
      tag_context[:foo] = {bar: "baz", far: "qux"}
      expect(tag_context.to_h).to eq({"foo.bar" => "baz", "foo.far" => "qux"})
    end

    it "returns a hash with subattributes" do
      tag_context.update(foo: {bar: "baz", far: "qux"})
      expect(tag_context[:foo]).to eq({"bar" => "baz", "far" => "qux"})
    end

    it "returns has deeply nested attributes" do
      tag_context.update(a: {b: {c: {d: 4, e: 5}, f: 6}, g: 7})
      expect(tag_context[:a]).to eq({"b.c.d" => 4, "b.c.e" => 5, "b.f" => 6, "g" => 7})
      expect(tag_context["a.b"]).to eq({"c.d" => 4, "c.e" => 5, "f" => 6})
    end
  end

  describe "#delete" do
    it "removes specified attributes" do
      tag_context[:foo] = "bar"
      tag_context[:baz] = "boo"
      tag_context[:qux] = "quux"
      expect(tag_context.to_h).to eq({"foo" => "bar", "baz" => "boo", "qux" => "quux"})
      tag_context.delete(:foo, :baz)
      expect(tag_context.to_h).to eq({"qux" => "quux"})
    end

    it "removes subattributes" do
      tag_context.update(foo: {bar: "baz", far: "qux"})
      expect(tag_context.to_h).to eq({"foo.bar" => "baz", "foo.far" => "qux"})
      tag_context.delete(:foo)
      expect(tag_context.to_h).to eq({})
    end
  end
end
