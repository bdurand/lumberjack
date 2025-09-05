# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Formatter::ObjectFormatter do
  it "is registered as :object" do
    expect(Lumberjack::FormatterRegistry.formatter(:object)).to be_a(Lumberjack::Formatter::ObjectFormatter)
  end

  it "should return the object itself" do
    formatter = Lumberjack::Formatter::ObjectFormatter.new
    obj = Object.new
    expect(formatter.call(obj).object_id).to eq obj.object_id
  end
end
