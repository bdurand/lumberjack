require "spec_helper"

describe Lumberjack::Formatter::ObjectFormatter do
  it "should return the object itself" do
    formatter = Lumberjack::Formatter::ObjectFormatter.new
    obj = Object.new
    expect(formatter.call(obj).object_id).to eq obj.object_id
  end
end
