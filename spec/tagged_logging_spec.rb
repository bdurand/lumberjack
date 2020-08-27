require "spec_helper"

if defined?(ActiveSupport::TaggedLogging)
  unless ActiveSupport::TaggedLogging.include?(Lumberjack::TaggedLogging)
    ActiveSupport::TaggedLogging.include(Lumberjack::TaggedLogging)
  end

  describe Lumberjack::TaggedLogging do
    let(:output) { StringIO.new }

    it "should wrap a Lumberjack logger as a tagged logger" do
      logger = Lumberjack::Logger.new(output, template: ":message - :tags")
      tagged_logger = ActiveSupport::TaggedLogging.new(logger)
      tagged_logger.tagged("foo", "bar") { tagged_logger.info("test") }
      expect(output.string.chomp).to eq 'test - [tagged:["foo", "bar"]]'
    end

    it "should return an already wrapped Lumberjack logger" do
      logger = Lumberjack::Logger.new(output, template: ":message - :tags").tagged_logger!
      tagged_logger = ActiveSupport::TaggedLogging.new(logger)
      expect(logger).to eq tagged_logger
      tagged_logger.tagged("foo", "bar") { tagged_logger.info("test") }
      expect(output.string.chomp).to eq 'test - [tagged:["foo", "bar"]]'
    end

    it "should wrap other kinds of logger with ActiveSupport Tagged logger" do
      logger = ::Logger.new(output)
      tagged_logger = ActiveSupport::TaggedLogging.new(logger)
      tagged_logger.tagged("foo", "bar") { tagged_logger.info("test") }
      expect(output.string.chomp).to eq "[foo] [bar] test"
    end
  end
end
