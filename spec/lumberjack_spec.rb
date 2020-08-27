require 'spec_helper'

describe Lumberjack do

  describe "context" do
    it "should create a context with tags for a block" do
      Lumberjack.context do
        Lumberjack.tag(foo: "bar")
        expect(Lumberjack.context[:foo]).to eq "bar"
      end
    end

    it "should always return a context" do
      context = Lumberjack.context
      expect(context).to be_a(Lumberjack::Context)
      expect(context).to_not eq(Lumberjack.context)
    end

    it "should determine if it is inside a context block" do
      expect(Lumberjack.context?).to eq false
      Lumberjack.context do
        expect(Lumberjack.context?).to eq true
      end
      expect(Lumberjack.context?).to eq false
    end

    it "should inherit parent context tags in sub blocks" do
      Lumberjack.context do
        Lumberjack.tag(foo: "bar")
        Lumberjack.context do
          expect(Lumberjack.context[:foo]).to eq "bar"
          Lumberjack.tag(foo: "baz")
          expect(Lumberjack.context[:foo]).to eq "baz"
        end
        expect(Lumberjack.context[:foo]).to eq "bar"
      end
      expect(Lumberjack.context[:foo]).to eq nil
    end

    it "should return the context tags or nil if there are no tags" do
      expect(Lumberjack.context_tags).to eq nil

      Lumberjack.tag(foo: "bar")
      expect(Lumberjack.context_tags).to eq nil

      Lumberjack.context do
        Lumberjack.tag(foo: "bar")
        expect(Lumberjack.context_tags).to eq("foo" => "bar")
      end
    end

    it "should be specify the context" do
      context = Lumberjack::Context.new
      context.tag(fog: "bar")
      Lumberjack.use_context(context) do
        expect(Lumberjack.context_tags).to eq("fog" => "bar")
      end
    end
  end

  describe "unit of work" do
    it "should create a unit work with a unique id in a block in a tag" do
      expect(Lumberjack.unit_of_work_id).to eq(nil)
      Lumberjack.unit_of_work do
        id_1 = Lumberjack.unit_of_work_id
        expect(id_1).to match(/^[0-9a-f]{12}$/)
        expect(Lumberjack.context[:unit_of_work_id]).to eq id_1
        Lumberjack.unit_of_work do
          id_2 = Lumberjack.unit_of_work_id
          expect(id_2).to match(/^[0-9a-f]{12}$/)
          expect(id_2).not_to eq(id_1)
          expect(Lumberjack.context[:unit_of_work_id]).to eq id_2
        end
        expect(id_1).to eq(Lumberjack.unit_of_work_id)
        expect(Lumberjack.context[:unit_of_work_id]).to eq id_1
      end
      expect(Lumberjack.unit_of_work_id).to eq(nil)
      expect(Lumberjack.context[:unit_of_work_id]).to eq nil
    end

    it "should allow you to specify a unit of work id for a block" do
      Lumberjack.unit_of_work("foo") do
        expect(Lumberjack.unit_of_work_id).to eq("foo")
      end
      expect(Lumberjack.unit_of_work_id).to eq(nil)
    end
  end

end
