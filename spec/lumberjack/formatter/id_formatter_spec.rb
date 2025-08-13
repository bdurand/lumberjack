# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Formatter::IdFormatter do
  it "should format an object as a hash of class and id" do
    obj = Object.new
    def obj.id
      1
    end
    formatter = Lumberjack::Formatter::IdFormatter.new
    expect(formatter.call(obj)).to eq({"class" => "Object", "id" => 1})
  end
end
