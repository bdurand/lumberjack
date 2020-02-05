require 'spec_helper'

describe Lumberjack::Formatter::StructuredFormatter do

  it "should recursively format arrays and hashes" do
    formatter = Lumberjack::Formatter.new.clear
    formatter.add(Enumerable, Lumberjack::Formatter::StructuredFormatter.new(formatter))
    formatter.add(String) { |obj| "#{obj}?"}
    formatter.add(Object, :object)
    formatted = formatter.format({ foo: "bar", baz: [1, 2, "three", { four: "four" }] })
    expect(formatted).to eq({ "foo" => "bar?", "baz" => [1, 2, "three?", { "four" => "four?" }] })
  end

  it "should not get into an infinite loop" do
    formatter = Lumberjack::Formatter.new.clear
    formatter.add(Enumerable, Lumberjack::Formatter::StructuredFormatter.new(formatter))
    formatter.add(Object, :object)
    object = { name: "object", children: [] }
    object[:parent] = object
    child_1 = { name: "child_1", parent: object }
    child_2 = { name: "child_2", parent: child_1 }
    object[:children] << child_1
    object[:children] << child_2
    formatted = formatter.format(object)
    expect(formatted).to eq({ "name" => "object", "children" => [{ "name" => "child_1" }, { "name" => "child_2" }] })
  end

end
