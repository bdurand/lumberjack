require "spec_helper"

describe Lumberjack::Tags do

  describe "stringify_keys" do
    it "transforms hash keys to strings" do
      hash = {foo: 1, bar: 2}
      expect(Lumberjack::Tags.stringify_keys(hash)).to eq({"foo" => 1, "bar" => 2})
    end

    it "returns the hash itself if the keys are already strings" do
      hash = {"foo" => 1, "bar" => 2}
      expect(Lumberjack::Tags.stringify_keys(hash).object_id).to eq(hash.object_id)
    end

    it "transforms hash keys to strings on older version of ruby" do
      hash = {foo: 1, bar: 2}
      expect(hash).to receive(:respond_to?).with(:transform_keys).and_return(false)
      expect(Lumberjack::Tags.stringify_keys(hash)).to eq({"foo" => 1, "bar" => 2})
    end
  end

end
