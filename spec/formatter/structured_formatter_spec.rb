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

end
