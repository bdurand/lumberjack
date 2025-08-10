require "spec_helper"

RSpec.describe Lumberjack do
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

    it "should return the result of the context block" do
      result = Lumberjack.context { :foo }
      expect(result).to eq :foo
    end

    it "should return the result of the use_context block" do
      result = Lumberjack.use_context(nil) { :foo }
      expect(result).to eq :foo
    end
  end
end
