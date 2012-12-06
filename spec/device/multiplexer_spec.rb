require 'spec_helper'

describe Lumberjack::Device::Multiplexer do

  it "should proxy to its devices" do
    d1 = mock("device1")
    d2 = mock("device2")
    [d1, d2].each { |d| d.should_receive(:write).with("message")}
    mp = Lumberjack::Device::Multiplexer.new([d1,d2])
    mp.write("message")
  end

end
