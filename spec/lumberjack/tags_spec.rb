# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Tags do
  describe "stringify_keys" do
    it "transforms hash keys to strings" do
      silence_deprecations do
        hash = {foo: 1, bar: 2}
        expect(Lumberjack::Tags.stringify_keys(hash)).to eq({"foo" => 1, "bar" => 2})
      end
    end

    it "returns the hash itself if the keys are already strings" do
      silence_deprecations do
        hash = {"foo" => 1, "bar" => 2}
        expect(Lumberjack::Tags.stringify_keys(hash).object_id).to eq(hash.object_id)
      end
    end
  end
end
