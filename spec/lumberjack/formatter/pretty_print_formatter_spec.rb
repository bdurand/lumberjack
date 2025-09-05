# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Formatter::PrettyPrintFormatter do
  it "is registered as :pretty_print" do
    expect(Lumberjack::FormatterRegistry.formatter(:pretty_print)).to be_a(Lumberjack::Formatter::PrettyPrintFormatter)
  end

  it "should convert an object to a string using pretty print" do
    object = Object.new
    def object.pretty_print(q)
      q.text "woot!"
    end
    formatter = Lumberjack::Formatter::PrettyPrintFormatter.new
    expect(formatter.call(object)).to eq("woot!")
  end
end
