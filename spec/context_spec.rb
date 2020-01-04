require "spec_helper"

describe Lumberjack::Context do

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

end
