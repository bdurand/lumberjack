# frozen_string_literal: true

require_relative "../../spec_helper"

RSpec.describe Lumberjack::LogEntryMatcher::IndifferentHash do
  let(:hash) { Lumberjack::LogEntryMatcher::IndifferentHash.wrap({"foo" => "bar"}.merge(baz: "boo")) }

  it "looks up values with either string or symbol keys" do
    expect(hash["foo"]).to eq "bar"
    expect(hash[:foo]).to eq "bar"
    expect(hash["baz"]).to eq "boo"
    expect(hash[:baz]).to eq "boo"
    expect(hash["nope"]).to be_nil
    expect(hash[:nope]).to be_nil
  end

  it "keeps the original keys" do
    expect(hash.keys).to eq ["foo", :baz]
    expect(hash).to eq({"foo" => "bar"}.merge(baz: "boo"))
  end

  it "checks for keys in either form" do
    expect(hash.key?("foo")).to be true
    expect(hash.key?(:foo)).to be true
    expect(hash.include?(:foo)).to be true
    expect(hash.has_key?(:foo)).to be true
    expect(hash.member?(:foo)).to be true
    expect(hash.key?("nope")).to be false
    expect(hash.key?(:nope)).to be false
    expect(hash.key?(1)).to be false
  end

  it "fetches values with either form" do
    expect(hash.fetch(:foo)).to eq "bar"
    expect(hash.fetch("baz")).to eq "boo"
    expect(hash.fetch(:nope, "default")).to eq "default"
    expect(hash.fetch(:nope) { "block" }).to eq "block"
    expect { hash.fetch(:nope) }.to raise_error(KeyError)
  end

  it "returns values at multiple keys with either form" do
    expect(hash.values_at(:foo, "baz")).to eq ["bar", "boo"]
  end

  it "wraps nested hashes and hashes inside arrays" do
    nested = Lumberjack::LogEntryMatcher::IndifferentHash.wrap({foo: {"bar" => {baz: "boo"}}, list: [{"a" => 1}]})
    expect(nested.dig("foo", :bar, "baz")).to eq "boo"
    expect(nested["foo"]["bar"][:baz]).to eq "boo"
    expect(nested[:list].first[:a]).to eq 1
  end

  it "returns non hash values as is" do
    expect(Lumberjack::LogEntryMatcher::IndifferentHash.wrap("foo")).to eq "foo"
    expect(Lumberjack::LogEntryMatcher::IndifferentHash.wrap(nil)).to be_nil
  end

  it "does not rewrap a hash that is already indifferent" do
    expect(Lumberjack::LogEntryMatcher::IndifferentHash.wrap(hash)).to be hash
  end
end
