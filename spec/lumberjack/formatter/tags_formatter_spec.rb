# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Formatter::TagsFormatter do
  describe "#call" do
    it "formats a hash of tags" do
      formatter = Lumberjack::Formatter::TagsFormatter.new
      tags = {foo: "bar", baz: "qux"}
      expect(formatter.call(tags)).to eq("[foo=bar] [baz=qux]")
    end

    it "formats an array of tags" do
      formatter = Lumberjack::Formatter::TagsFormatter.new
      tags = ["foo", "bar"]
      expect(formatter.call(tags)).to eq("[foo] [bar]")
    end

    it "returns a string for a single tag" do
      formatter = Lumberjack::Formatter::TagsFormatter.new
      tags = "foo"
      expect(formatter.call(tags)).to eq("[foo]")
    end

    it "formats hashes inside arrays" do
      formatter = Lumberjack::Formatter::TagsFormatter.new
      tags = [{foo: "bar"}, {baz: "qux"}]
      expect(formatter.call(tags)).to eq("[foo=bar] [baz=qux]")
    end

    it "formats mixed arrays" do
      formatter = Lumberjack::Formatter::TagsFormatter.new
      tags = ["foo", {bar: "baz", fip: "fop"}]
      expect(formatter.call(tags)).to eq("[foo] [bar=baz] [fip=fop]")
    end
  end
end
