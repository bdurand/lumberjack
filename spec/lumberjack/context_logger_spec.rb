# frozen_string_literal: true

require "spec_helper"

describe Lumberjack::ContextLogger do
  let(:logger) { TestContextLogger.new }
  let(:logger_with_default_context) { TestContextLogger.new(default_context) }
  let(:default_context) { Lumberjack::Context.new }

  describe "#level" do
    it "can be nil" do
      expect(logger.level).to be_nil
      logger.level = nil
      expect(logger.level).to be_nil
    end

    it "sets the default level if the logger has a default context" do
      logger_with_default_context.level = Logger::INFO
      expect(logger_with_default_context.level).to eq(Logger::INFO)
    end

    it "has no effect outside a context block if the logger does not have a default context" do
      logger.level = Logger::INFO
      expect(logger.level).to be_nil
    end

    it "sets a temporary level within a block" do
      logger.context do
        logger.level = Logger::DEBUG
        expect(logger.level).to eq(Logger::DEBUG)
      end
      expect(logger.level).to be_nil
    end

    it "can set the value with a symbol" do
      logger_with_default_context.level = :info
      expect(logger_with_default_context.level).to eq(Logger::INFO)
    end

    it "can set the value with a string" do
      logger_with_default_context.level = "INFO"
      expect(logger_with_default_context.level).to eq(Logger::INFO)
    end
  end

  describe "#with_level" do
    it "sets a temporary level within the block" do
      logger.with_level(Logger::ERROR) do
        expect(logger.level).to eq(Logger::ERROR)
      end
      expect(logger.level).to be_nil
    end

    it "is only affects the level for the current fiber" do
      fiber_1 = Fiber.new do
        logger.with_level(Logger::ERROR) do
          expect(logger.level).to eq(Logger::ERROR)
          Fiber.yield
        end
        expect(logger.level).to be_nil
      end

      fiber_2 = Fiber.new do
        logger.with_level(Logger::WARN) do
          expect(logger.level).to eq(Logger::WARN)
          fiber_1.resume
        end
        expect(logger.level).to be_nil
      end.resume
    end
  end

  describe "#progname" do
    it "returns the progname from the default context" do
      logger_with_default_context.progname = "TestProgname"
      expect(logger_with_default_context.progname).to eq("TestProgname")
    end

    it "returns nil if the logger does not have a default context" do
      expect(logger.progname).to be_nil
    end

    it "returns the progname from the current context" do
      logger.context do
        logger.progname = "TestProgname"
        expect(logger.progname).to eq("TestProgname")
      end
      expect(logger.progname).to be_nil
    end
  end

  describe "#with_progname" do
    it "sets a temporary progname within the block" do
      logger.with_progname("TestProgname") do
        expect(logger.progname).to eq("TestProgname")
      end
      expect(logger.progname).to be_nil
    end

    it "is only affects the progname for the current fiber" do
      fiber_1 = Fiber.new do
        logger.with_progname("TestProgname") do
          expect(logger.progname).to eq("TestProgname")
          Fiber.yield
        end
        expect(logger.progname).to be_nil
      end

      fiber_2 = Fiber.new do
        logger.with_progname("AnotherProgname") do
          expect(logger.progname).to eq("AnotherProgname")
          fiber_1.resume
        end
        expect(logger.progname).to be_nil
      end.resume
    end
  end

  describe "#add" do
    it "adds a message to the log" do
      logger.add(Logger::INFO, "Test message")
      expect(logger.entries.last).to eq({
        severity: Logger::INFO,
        message: "Test message",
        progname: nil,
        tags: nil
      })
    end

    it "does not add a message if the severity is less than the level" do
      logger.with_level(:warn) do
        logger.add(Logger::INFO, "Test message")
      end
      expect(logger.entries).to be_empty
    end

    it "adds the entry as UNKNOWN if the severity is not specified" do
      logger.add(nil, "Test message")
      expect(logger.entries.last).to eq({
        severity: Logger::UNKNOWN,
        message: "Test message",
        progname: nil,
        tags: nil
      })
    end

    it "is aliased as #log" do
      logger.add(Logger::INFO, "Test message")
      logger.log(Logger::INFO, "Test message")
      expect(logger.entries[0]).to eq(logger.entries[1])
    end
  end

  describe "#<<" do
    it "appends a message to the log"
  end

  describe "#context" do
    it "creates isolated contexts in nested block" do
      logger.context do
        logger.level = :debug
        logger.progname = "Temp"
        logger.tag(foo: "bar")
        expect(logger.level).to eq(Logger::DEBUG)
        expect(logger.progname).to eq("Temp")
        expect(logger.tags).to eq({"foo" => "bar"})

        logger.context do
          expect(logger.level).to eq(Logger::DEBUG)
          expect(logger.progname).to eq("Temp")
          expect(logger.tags).to eq({"foo" => "bar"})

          logger.level = :info
          logger.progname = "Inner"
          logger.tag(baz: "qux")
          expect(logger.level).to eq(Logger::INFO)
          expect(logger.progname).to eq("Inner")
          expect(logger.tags).to eq({"foo" => "bar", "baz" => "qux"})
        end

        expect(logger.level).to eq(Logger::DEBUG)
        expect(logger.progname).to eq("Temp")
        expect(logger.tags).to eq({"foo" => "bar"})
      end

      expect(logger.level).to be_nil
      expect(logger.progname).to be_nil
      expect(logger.tags).to be_empty
    end

    it "returns the result of the block" do
      result = logger.context { :foobar }
      expect(result).to eq(:foobar)
    end

    it "returns the current context without a block" do
      context = logger.context
      expect(context).to be_a(Lumberjack::Context)
    end

    it "yields the context" do
      logger.context do |ctx|
        expect(ctx).to be_a(Lumberjack::Context)
      end
    end
  end

  describe "#in_context?" do
    it "returns true inside a context block" do
      expect(logger.in_context?).to be false
      logger.context do
        expect(logger.in_context?).to be true
      end
      expect(logger.in_context?).to be false
    end
  end

  describe "#tag" do
    it "adds tags inside of a block" do
      logger.tag(foo: "bar") do
        expect(logger.tags).to eq({"foo" => "bar"})
      end
      expect(logger.tags).to be_empty
    end

    it "merges tags in nested blocks" do
      logger.tag(foo: "bar") do
        logger.tag(baz: "qux") do
          expect(logger.tags).to eq({"foo" => "bar", "baz" => "qux"})
        end
        expect(logger.tags).to eq({"foo" => "bar"})
      end
      expect(logger.tags).to be_empty
    end

    it "flattens nested tags" do
      logger.tag(foo: {bar: "baz", far: "qux"}) do
        expect(logger.tags).to eq({"foo.bar" => "baz", "foo.far" => "qux"})
      end
    end

    it "adds new tags to the current context without a block" do
      logger.context do
        logger.tag(foo: "bar")
        logger.tag(baz: "qux")
        expect(logger.tags).to eq({"foo" => "bar", "baz" => "qux"})
      end
      expect(logger.tags).to be_empty
    end

    it "returns the result of the block" do
      result = logger.tag(foo: "bar") { :foobar }
      expect(result).to eq(:foobar)
    end

    it "returns self when called inside a context without a block" do
      logger.context do
        expect(logger.tag(foo: "bar")).to eq(logger)
      end
    end

    it "returns a new context logger with the tags if there is no current context" do
      new_logger = logger.tag(foo: "bar")
      expect(new_logger.tags).to eq({"foo" => "bar"})
      expect(new_logger).to_not eq(logger)
      expect(new_logger).to be_a(Lumberjack::ContextLogger)
    end
  end

  describe "#tag!" do
    it "adds tags to the default context" do
      logger_with_default_context.tag!(foo: "bar")
      expect(logger_with_default_context.tags).to eq({"foo" => "bar"})
      logger_with_default_context.tag!(baz: "qux")
      expect(logger_with_default_context.tags).to eq({"foo" => "bar", "baz" => "qux"})
    end

    it "does nothing if there is no default context" do
      logger.tag!(foo: "bar")
      expect(logger.tags).to be_empty
    end
  end

  describe "#untag" do
    it "removes tags from the current context block" do
      logger.tag(foo: "bar", baz: "qux", bip: "bap") do
        logger.untag(:foo, "baz")
        expect(logger.tags).to eq({"bip" => "bap"})
      end
    end

    it "does nothing outside of a context block" do
      logger_with_default_context.tag!(foo: "bar")
      logger_with_default_context.untag(:foo)
      expect(logger_with_default_context.tags).to eq({"foo" => "bar"})
    end
  end

  describe "#untag!" do
    it "removes tags from the default context" do
      logger_with_default_context.tag!(foo: "bar", baz: "qux", bip: "bap")
      logger_with_default_context.untag!(:foo, "baz")
      expect(logger_with_default_context.tags).to eq({"bip" => "bap"})
    end

    it "does nothing if the logger does not have a default context" do
      logger.untag!(:foo)
      expect(logger.tags).to be_empty
    end
  end

  describe "#tags" do
    it "returns an empty hash by default" do
      expect(logger.tags).to eq({})
      expect(logger_with_default_context.tags).to eq({})
    end

    it "returns tags from the default context" do
      logger_with_default_context.tag!(foo: "bar")
      expect(logger_with_default_context.tags).to eq({"foo" => "bar"})
    end

    it "returns tags from the current context" do
      logger.tag(foo: "bar") do
        expect(logger.tags).to eq({"foo" => "bar"})
      end
    end

    it "merges tags from the current context with the default context tags" do
      logger_with_default_context.tag!(foo: "bar")
      logger_with_default_context.tag(baz: "qux") do
        expect(logger_with_default_context.tags).to eq({"foo" => "bar", "baz" => "qux"})
      end
      expect(logger_with_default_context.tags).to eq({"foo" => "bar"})
    end

    it "includes tags from the global context" do
      Lumberjack.tag(foo: "bar") do
        logger.tag(baz: "qux") do
          expect(logger.tags).to eq({"foo" => "bar", "baz" => "qux"})
        end
        expect(logger.tags).to eq({"foo" => "bar"})
      end
    end

    it "prefers tags from the most local context" do
      Lumberjack.tag(foo: "one") do
        expect(logger.tags["foo"]).to eq("one")

        logger_with_default_context.tag!(foo: "two")
        expect(logger_with_default_context.tags["foo"]).to eq("two")

        logger_with_default_context.tag(foo: "three") do
          expect(logger.tag_value("foo")).to eq("three")
        end
      end
    end
  end

  describe "#tag_value" do
    it "returns the value of a tag" do
      Lumberjack.tag(foo: "bar") do
        logger_with_default_context.tag!(baz: "qux")
        logger_with_default_context.tag(bip: "bap") do
          expect(logger.tag_value("foo")).to eq("bar")
          expect(logger.tag_value("baz")).to eq("qux")
          expect(logger.tag_value("bip")).to eq("bap")
        end
      end
    end
  end

  describe "#untagged" do
    it "removes all tags from the current, default, and global contexts for the duration of the block" do
      Lumberjack.tag(foo: "bar") do
        logger_with_default_context.tag!(baz: "qux")
        logger_with_default_context.tag(bip: "bap") do
          expect(logger_with_default_context.tags.length).to eq(3)

          logger_with_default_context.untagged do
            expect(logger_with_default_context.tags).to be_empty

            logger_with_default_context.tag(moo: "mip") do
              expect(logger_with_default_context.tags).to eq({"moo" => "mip"})
            end
          end
        end
      end
    end

    it "returns the result of the block" do
      result = logger.untagged { :foobar }
      expect(result).to eq(:foobar)
    end
  end

  [:fatal, :error, :warn, :info, :debug, :unknown].each do |severity|
    describe "##{severity}" do
      it "logs an entry as #{severity}" do
        logger.public_send(severity, "Message")
        expect(logger.entries.first).to eq({
          severity: Logger.const_get(severity.to_s.upcase),
          message: "Message",
          progname: nil,
          tags: nil
        })
      end

      it "logs an entry as #{severity} with the message in a block" do
        logger.public_send(severity) { "Message" }
        expect(logger.entries.first).to eq({
          severity: Lumberjack::Severity.coerce(severity),
          message: "Message",
          progname: nil,
          tags: nil
        })
      end

      it "logs an entry as #{severity} with a progname" do
        logger.public_send(severity, "Message", "myApp")
        expect(logger.entries.first).to eq({
          severity: Lumberjack::Severity.coerce(severity),
          message: "Message",
          progname: "myApp",
          tags: nil
        })
      end

      it "logs an entry as #{severity} with tags" do
        logger.public_send(severity, "Message", foo: "bar")
        expect(logger.entries.first).to eq({
          severity: Lumberjack::Severity.coerce(severity),
          message: "Message",
          progname: nil,
          tags: {foo: "bar"}
        })
      end

      it "logs an entry as #{severity} with tags and the message in a block" do
        logger.public_send(severity, foo: "bar") { "Message" }
        expect(logger.entries.first).to eq({
          severity: Lumberjack::Severity.coerce(severity),
          message: "Message",
          progname: nil,
          tags: {foo: "bar"}
        })
      end

      it "does not log an entry if the level is greater than #{severity}" do
        logger.with_level(Lumberjack::Severity.coerce(severity) + 1) do
          logger.public_send(severity) { raise NotImplementedError }
          expect(logger.entries).to be_empty
        end
      end
    end
  end

  describe "#fatal?" do
    it "is true if the level is fatal or less" do
      logger_with_default_context.level = :fatal
      expect(logger_with_default_context.fatal?).to be true
      logger_with_default_context.level = Logger::UNKNOWN
      expect(logger_with_default_context.fatal?).to be false
    end
  end

  describe "#error?" do
    it "is true if the level is error or less" do
      logger_with_default_context.level = :error
      expect(logger_with_default_context.error?).to be true
      logger_with_default_context.level = :fatal
      expect(logger_with_default_context.error?).to be false
    end
  end

  describe "#warn?" do
    it "is true if the level is warn or less" do
      logger_with_default_context.level = :warn
      expect(logger_with_default_context.warn?).to be true
      logger_with_default_context.level = :error
      expect(logger_with_default_context.warn?).to be false
    end
  end

  describe "#info?" do
    it "is true if the level is info or less" do
      logger_with_default_context.level = :info
      expect(logger_with_default_context.info?).to be true
      logger_with_default_context.level = :warn
      expect(logger_with_default_context.info?).to be false
    end
  end

  describe "#debug?" do
    it "is true if the level is debug or less" do
      logger_with_default_context.level = :debug
      expect(logger_with_default_context.debug?).to be true
      logger_with_default_context.level = :info
      expect(logger_with_default_context.debug?).to be false
    end
  end

  describe "#fatal!" do
    it "sets the level to fatal" do
      logger_with_default_context.fatal!
      expect(logger_with_default_context.level).to eq(Logger::FATAL)
    end

    it "temporarily sets the level to fatal in a context block" do
      logger do
        logger.fatal!
        expect(logger.level).to eq(Logger::FATAL)
      end
      expect(logger.level).to be_nil
    end

    it "has no effect outside the context block without a default context" do
      logger.fatal!
      expect(logger.level).to be_nil
    end
  end

  describe "#error!" do
    it "sets the level to error" do
      logger_with_default_context.error!
      expect(logger_with_default_context.level).to eq(Logger::ERROR)
    end

    it "temporarily sets the level to error in a context block" do
      logger do
        logger.error!
        expect(logger.level).to eq(Logger::ERROR)
      end
      expect(logger.level).to be_nil
    end

    it "has no effect outside the context block without a default context" do
      logger.error!
      expect(logger.level).to be_nil
    end
  end

  describe "#warn!" do
    it "sets the level to warn" do
      logger_with_default_context.warn!
      expect(logger_with_default_context.level).to eq(Logger::WARN)
    end

    it "temporarily sets the level to warn in a context block" do
      logger do
        logger.warn!
        expect(logger.level).to eq(Logger::WARN)
      end
      expect(logger.level).to be_nil
    end

    it "has no effect outside the context block without a default context" do
      logger.warn!
      expect(logger.level).to be_nil
    end
  end

  describe "#info!" do
    it "sets the level to info" do
      logger_with_default_context.info!
      expect(logger_with_default_context.level).to eq(Logger::INFO)
    end

    it "temporarily sets the level to info in a context block" do
      logger do
        logger.info!
        expect(logger.level).to eq(Logger::INFO)
      end
      expect(logger.level).to be_nil
    end

    it "has no effect outside the context block without a default context" do
      logger.info!
      expect(logger.level).to be_nil
    end
  end

  describe "#debug!" do
    it "sets the level to debug" do
      logger_with_default_context.debug!
      expect(logger_with_default_context.level).to eq(Logger::DEBUG)
    end

    it "temporarily sets the level to debug in a context block" do
      logger do
        logger.debug!
        expect(logger.level).to eq(Logger::DEBUG)
      end
      expect(logger.level).to be_nil
    end

    it "has no effect outside the context block without a default context" do
      logger.debug!
      expect(logger.level).to be_nil
    end
  end
end
