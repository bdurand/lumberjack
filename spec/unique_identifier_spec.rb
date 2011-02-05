require 'spec_helper'

describe Lumberjack::UniqueIdentifier do
 
  it "should create 12 byte unique identifiers" do
    id_1 = Lumberjack::UniqueIdentifier.new
    id_2 = Lumberjack::UniqueIdentifier.new
    id_1.should_not == id_2
    id_1.to_s.size.should == 24
    id_2.to_s.size.should == 24
  end

end
