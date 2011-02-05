require 'spec_helper'

describe Lumberjack do
  
  context "unit of work" do
    it "should create a unit work with a unique id in a block" do
      Lumberjack.unit_of_work_id.should == nil
      Lumberjack.unit_of_work do
        id_1 = Lumberjack.unit_of_work_id
        id_1.should be_a(Lumberjack::UniqueIdentifier)
        Lumberjack.unit_of_work do
          id_2 = Lumberjack.unit_of_work_id
          id_2.should be_a(Lumberjack::UniqueIdentifier)
          id_2.should_not == id_1
        end
        id_1.should == Lumberjack.unit_of_work_id
      end
      Lumberjack.unit_of_work_id.should == nil
    end
  end
  
end
