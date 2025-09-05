# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::FormatterRegistry do
  after do
    Lumberjack::FormatterRegistry.remove(:test)
  end

  it "can add a formatter as a block" do
    expect(Lumberjack::FormatterRegistry.registered?(:test)).to be false
    Lumberjack::FormatterRegistry.add(:test) { |value| value.to_s.upcase }
    expect(Lumberjack::FormatterRegistry.registered?(:test)).to be true
    formatter = Lumberjack::FormatterRegistry.formatter(:test)
    expect(formatter.call("Test")).to eq("TEST")
  end

  it "can add a formatter with an object" do
    formatter = lambda { |value| value.to_s.capitalize }
    Lumberjack::FormatterRegistry.add(:test, formatter)
    expect(Lumberjack::FormatterRegistry.formatter(:test)).to eq(formatter)
  end

  it "can add a formatter as a class" do
    Lumberjack::FormatterRegistry.add(:test, Lumberjack::Formatter::TruncateFormatter)
    formatter = Lumberjack::FormatterRegistry.formatter(:test, 3)
    expect(formatter.call("Test")).to eq("Te…")
  end

  it "raises an error if the formatter is not registered" do
    expect { Lumberjack::FormatterRegistry.formatter(:unknown) }.to raise_error(ArgumentError)
  end
end
