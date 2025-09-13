# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Formatter::TaggedMessage, deprecation_mode: :silent do
  it "is a MessageAttributes" do
    obj = Lumberjack::Formatter::TaggedMessage.new("foo", bar: "baz")
    expect(obj).to be_a(Lumberjack::MessageAttributes)
  end
end
