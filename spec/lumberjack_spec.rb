require 'spec_helper'

describe Lumberjack do
  
  context "unit of work" do
    it "should create a unit work with a unique id in a block" do
      expect(Lumberjack.unit_of_work_id).to eq(nil)
      Lumberjack.unit_of_work do
        id_1 = Lumberjack.unit_of_work_id
        expect(id_1).to match(/^[0-9a-f]{12}$/)
        Lumberjack.unit_of_work do
          id_2 = Lumberjack.unit_of_work_id
          expect(id_2).to match(/^[0-9a-f]{12}$/)
          expect(id_2).not_to eq(id_1)
        end
        expect(id_1).to eq(Lumberjack.unit_of_work_id)
      end
      expect(Lumberjack.unit_of_work_id).to eq(nil)
    end
    
    it "should allow you to specify a unit of work id for a block" do
      Lumberjack.unit_of_work("foo") do
        expect(Lumberjack.unit_of_work_id).to eq("foo")
      end
      expect(Lumberjack.unit_of_work_id).to eq(nil)
    end
  end
  
end
