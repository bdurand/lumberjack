# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Formatter::TagsFormatter do
  it "is registered as :tags" do
    expect(Lumberjack::FormatterRegistry.formatter(:tags)).to be_a(Lumberjack::Formatter::TagsFormatter)
  end

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

    it "formats non-string tag values" do
      formatter = Lumberjack::Formatter::TagsFormatter.new
      expect(formatter.call([1, 2])).to eq("[1] [2]")
      expect(formatter.call(3)).to eq("[3]")
      expect(formatter.call([{count: 5}])).to eq("[count=5]")
    end

    it "returns an empty string for an empty array" do
      formatter = Lumberjack::Formatter::TagsFormatter.new
      expect(formatter.call([])).to eq("")
    end
  end
end
