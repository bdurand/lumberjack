require "spec_helper"

RSpec.describe Lumberjack::TaggedLoggerSupport do
  let(:output) { StringIO.new }
  let(:device) { Lumberjack::Device::Writer.new(output, buffer_size: 0, template: ":message - :count - :tags") }
  let(:logger) { Lumberjack::Logger.new(device).tagged_logger! }

  describe "logger" do
    describe "tagged" do
      it "should add global tags to the logger with no block" do
        logger.tagged("foo", "bar")
        logger.info("message", count: 1)
        line = output.string.chomp
        expect(line).to eq 'message - 1 - [tagged:["foo", "bar"]]'
      end

      it "should add tags to the tag 'tagged'" do
        logger.tagged("foo", "bar") do
          logger.info("message", count: 1)
        end
        line = output.string.chomp
        expect(line).to eq 'message - 1 - [tagged:["foo", "bar"]]'
      end

      it "should handle non-string tags" do
        logger.tagged(15) do
          logger.info("message")
        end
        line = output.string.chomp
        expect(line).to eq 'message -  - [tagged:["15"]]'
      end

      it "should be nestable" do
        logger.tagged("foo") do
          logger.tagged("bar") do
            logger.info("message", count: 1)
          end
        end
        line = output.string.chomp
        expect(line).to eq 'message - 1 - [tagged:["foo", "bar"]]'
      end
    end

    describe "push_tags" do
      it "should push tag from the logger" do
        logger.push_tags("foo", "bar")
        expect(logger.tags).to eq({"tagged" => ["foo", "bar"]})
        logger.push_tags("baz")
        expect(logger.tags).to eq({"tagged" => ["foo", "bar", "baz"]})
      end

      it "should push tags in a context" do
        logger.push_tags("foo")
        logger.context do
          logger.push_tags(["bar"])
          expect(logger.tags).to eq({"tagged" => ["foo", "bar"]})
          logger.push_tags("baz")
          expect(logger.tags).to eq({"tagged" => ["foo", "bar", "baz"]})
        end
        expect(logger.tags).to eq({"tagged" => ["foo"]})
      end

      it "should not push empty tags" do
        logger.push_tags("", "foo", nil)
        expect(logger.tags).to eq({"tagged" => ["foo"]})
      end
    end

    describe "pop_tags" do
      it "should pop tags from the logger" do
        logger.push_tags("foo", "bar", "baz")
        logger.pop_tags
        expect(logger.tags).to eq({"tagged" => ["foo", "bar"]})
        logger.pop_tags(2)
        expect(logger.tags).to eq({"tagged" => nil})
      end

      it "should pop tags in a context" do
        logger.push_tags("foo")
        logger.context do
          logger.push_tags("bar", "baz")
          logger.pop_tags
          expect(logger.tags).to eq({"tagged" => ["foo", "bar"]})
          logger.pop_tags(2)
          expect(logger.tags).to eq({"tagged" => nil})
        end
        expect(logger.tags).to eq({"tagged" => ["foo"]})
      end
    end

    describe "clear_tags!" do
      it "should pop tags from the logger" do
        logger.push_tags("foo", "bar", "baz")
        logger.clear_tags!
        expect(logger.tags).to eq({"tagged" => nil})
      end

      it "should clear tags in a context" do
        logger.push_tags("foo")
        logger.context do
          logger.push_tags("bar", "baz")
          logger.clear_tags!
          expect(logger.tags).to eq({"tagged" => nil})
        end
        expect(logger.tags).to eq({"tagged" => ["foo"]})
      end
    end
  end

  describe "formatter" do
    let(:formatter) { logger.formatter }

    describe "tagged" do
      it "should add tags to the tag 'tagged'" do
        formatter.tagged("foo", "bar") do
          logger.info("message", count: 1)
        end
        line = output.string.chomp
        expect(line).to eq 'message - 1 - [tagged:["foo", "bar"]]'
      end
    end

    describe "push_tags" do
      it "should push tags from the formatter" do
        formatter.push_tags("foo", "bar")
        expect(logger.tags).to eq({"tagged" => ["foo", "bar"]})
        formatter.push_tags("baz")
        expect(logger.tags).to eq({"tagged" => ["foo", "bar", "baz"]})
      end
    end

    describe "pop_tags" do
      it "should pop tags from the formatter" do
        formatter.push_tags("foo", "bar", "baz")
        formatter.pop_tags
        expect(logger.tags).to eq({"tagged" => ["foo", "bar"]})
        formatter.pop_tags(2)
        expect(logger.tags).to eq({"tagged" => nil})
      end
    end

    describe "clear_tags!" do
      it "should pop tags from the formatter" do
        formatter.push_tags("foo", "bar", "baz")
        formatter.clear_tags!
        expect(logger.tags).to eq({"tagged" => nil})
      end
    end

    describe "current_tags" do
      it "should get the current tags from the formatter" do
        expect(formatter.current_tags).to eq []
        formatter.push_tags("foo", "bar", "baz")
        expect(formatter.current_tags).to eq ["foo", "bar", "baz"]
      end
    end

    describe "tag_text" do
      it "should return empty if there are no tags" do
        expect(formatter.tags_text).to eq nil
      end

      it "should return a string of tags" do
        formatter.push_tags("foo", "bar", "baz")
        expect(formatter.tags_text).to eq "[foo] [bar] [baz] "
      end
    end
  end
end
