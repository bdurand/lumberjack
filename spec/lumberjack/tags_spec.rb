# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Tags do
  describe "stringify_keys" do
    it "transforms hash keys to strings" do
      hash = {foo: 1, bar: 2}
      expect(Lumberjack::Tags.stringify_keys(hash)).to eq({"foo" => 1, "bar" => 2})
    end

    it "returns the hash itself if the keys are already strings" do
      hash = {"foo" => 1, "bar" => 2}
      expect(Lumberjack::Tags.stringify_keys(hash).object_id).to eq(hash.object_id)
    end
  end

  describe "expand_runtime_values" do
    it "should return a hash as is if there are no Procs" do
      hash = {"foo" => 1, "bar" => 2}
      expect(Lumberjack::Tags.expand_runtime_values(hash)).to eq(hash)
      expect(Lumberjack::Tags.expand_runtime_values(hash).object_id).to eq(hash.object_id)
    end

    it "should replace all keys with strings" do
      hash = {foo: 1, bar: 2}
      expect(Lumberjack::Tags.expand_runtime_values(hash)).to eq({"foo" => 1, "bar" => 2})
    end

    it "should replace Procs that take no arguments with the runtime value" do
      p1 = lambda { "stuff" }
      p2 = lambda { |x| x.upcase }
      hash = {foo: 1, bar: p1, baz: p2}
      expect(Lumberjack::Tags.expand_runtime_values(hash)).to eq({"foo" => 1, "bar" => "stuff", "baz" => p2})
    end
  end
end
