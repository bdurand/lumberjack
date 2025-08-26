# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Formatter::TaggedMessage do
  it "is a MessageAttributes" do
    silence_deprecations do
      obj = Lumberjack::Formatter::TaggedMessage.new("foo", bar: "baz")
      expect(obj).to be_a(Lumberjack::MessageAttributes)
    end
  end
end
