# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::ContextLogger do
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
      end

      fiber_2.resume
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
      end

      fiber_2.resume
    end
  end

  describe "#add" do
    it "returns true" do
      result = logger.add(Logger::INFO, "Test message")
      expect(result).to be true
    end

    it "adds a message to the log" do
      logger.add(Logger::INFO, "Test message")
      expect(logger.entries.last).to eq({
        severity: Logger::INFO,
        message: "Test message",
        progname: nil,
        attributes: nil
      })
    end

    it "adds a message with the progname" do
      logger.add(:info, "Test", "MyApp")
      expect(logger.entries.last).to eq(
        severity: Logger::INFO,
        message: "Test",
        progname: "MyApp",
        attributes: nil
      )
    end

    it "adds a message with attributes" do
      logger.add(:info, "Test", foo: "bar")
      expect(logger.entries.last).to eq(
        severity: Logger::INFO,
        message: "Test",
        progname: nil,
        attributes: {foo: "bar"}
      )
    end

    it "adds a message with the message in a block" do
      logger.add(:info) { "Test Message" }
      expect(logger.entries.last).to eq({
        severity: Logger::INFO,
        message: "Test Message",
        progname: nil,
        attributes: nil
      })
    end

    it "adds a message with attributes with the message in a block" do
      logger.add(:info, foo: "bar") { "Test Message" }
      expect(logger.entries.last).to eq({
        severity: Logger::INFO,
        message: "Test Message",
        progname: nil,
        attributes: {foo: "bar"}
      })
    end

    it "adds a message with a progname with the message in a block" do
      logger.add(:info, "MyApp") { "Test Message" }
      expect(logger.entries.last).to eq({
        severity: Logger::INFO,
        message: "Test Message",
        progname: "MyApp",
        attributes: nil
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
        attributes: nil
      })
    end

    it "adds the entry as UNKNOWN if severity is not specified and message is in a block" do
      logger.add(nil) { "Test message" }
      expect(logger.entries.last).to eq({
        severity: Logger::UNKNOWN,
        message: "Test message",
        progname: nil,
        attributes: nil
      })
    end

    it "strips whitespace from the message" do
      logger.add(Logger::INFO, "   Test message   ")
      expect(logger.entries.last[:message]).to eq("Test message")

      logger.add("\nTest message")
      expect(logger.entries.last[:message]).to eq("Test message")

      logger.add("Test message\n")
      expect(logger.entries.last[:message]).to eq("Test message")
    end

    it "is aliased as #log" do
      logger.add(Logger::INFO, "Test message")
      logger.log(Logger::INFO, "Test message")
      expect(logger.entries[0]).to eq(logger.entries[1])
    end
  end

  describe "#<<" do
    it "appends a message to the log" do
      logger << "Test message"
      expect(logger.entries.last).to eq({
        severity: Logger::UNKNOWN,
        message: "Test message",
        progname: nil,
        attributes: nil
      })
    end

    it "will use the default severity to log the message" do
      logger = TestContextLogger.new(Lumberjack::Context.new)
      logger.default_severity = :info
      logger << "Test message"
      expect(logger.entries.last).to eq({
        severity: Logger::INFO,
        message: "Test message",
        progname: nil,
        attributes: nil
      })
    end
  end

  describe "#context" do
    it "creates isolated contexts in nested block" do
      logger.context do
        logger.level = :debug
        logger.progname = "Temp"
        logger.tag(foo: "bar")
        expect(logger.level).to eq(Logger::DEBUG)
        expect(logger.progname).to eq("Temp")
        expect(logger.attributes).to eq({"foo" => "bar"})

        logger.context do
          expect(logger.level).to eq(Logger::DEBUG)
          expect(logger.progname).to eq("Temp")
          expect(logger.attributes).to eq({"foo" => "bar"})

          logger.level = :info
          logger.progname = "Inner"
          logger.tag(baz: "qux")
          expect(logger.level).to eq(Logger::INFO)
          expect(logger.progname).to eq("Inner")
          expect(logger.attributes).to eq({"foo" => "bar", "baz" => "qux"})
        end

        expect(logger.level).to eq(Logger::DEBUG)
        expect(logger.progname).to eq("Temp")
        expect(logger.attributes).to eq({"foo" => "bar"})
      end

      expect(logger.level).to be_nil
      expect(logger.progname).to be_nil
      expect(logger.attributes).to be_empty
    end

    it "returns the result of the block" do
      result = logger.context { :foobar }
      expect(result).to eq(:foobar)
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

  describe "#ensure_context" do
    it "should create a context if one does not exist" do
      expect(logger.in_context?).to eq false
      value = logger.ensure_context do
        expect(logger.in_context?).to eq true
        :foo
      end
      expect(logger.in_context?).to eq false
      expect(value).to eq :foo
    end

    it "does not create a new context if one already exists" do
      logger.context do
        value = logger.ensure_context do
          logger.tag(baz: "bap")
          :foo
        end
        expect(logger.attributes).to eq({"baz" => "bap"})
        expect(value).to eq :foo
      end
    end
  end

  describe "#tag" do
    it "adds attributes inside of a block" do
      logger.tag(foo: "bar") do
        expect(logger.attributes).to eq({"foo" => "bar"})
      end
      expect(logger.attributes).to be_empty
    end

    it "merges attributes in nested blocks" do
      logger.tag(foo: "bar") do
        logger.tag(baz: "qux") do
          expect(logger.attributes).to eq({"foo" => "bar", "baz" => "qux"})
        end
        expect(logger.attributes).to eq({"foo" => "bar"})
      end
      expect(logger.attributes).to be_empty
    end

    it "flattens nested attributes" do
      logger.tag(foo: {bar: "baz", far: "qux"}) do
        expect(logger.attributes).to eq({"foo.bar" => "baz", "foo.far" => "qux"})
      end
    end

    it "adds new attributes to the current context without a block" do
      logger.context do
        logger.tag(foo: "bar")
        logger.tag(baz: "qux")
        expect(logger.attributes).to eq({"foo" => "bar", "baz" => "qux"})
      end
      expect(logger.attributes).to be_empty
    end

    it "works with a frozen hash" do
      logger.tag({foo: "bar"}.freeze) do
        logger.tag(baz: "qux")
        expect(logger.attributes).to eq({"foo" => "bar", "baz" => "qux"})
      end
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

    it "returns self without applying attributes if there is no current context" do
      expect(logger.tag(foo: "bar")).to equal(logger)
      expect(logger.attributes).to be_empty
    end
  end

  describe "#tag_all_contexts" do
    it "adds attributes to the parent contexts in the hierarchy" do
      logger.tag(foo: "bar") do
        logger.tag(baz: "qux") do
          logger.tag_all_contexts(bip: "bap")
          expect(logger.attributes).to eq({"foo" => "bar", "baz" => "qux", "bip" => "bap"})
        end
        expect(logger.attributes).to eq({"foo" => "bar", "bip" => "bap"})
      end
      expect(logger.attributes).to be_empty
    end

    it "does not attributes to the default context if there is no current context" do
      logger.tag_all_contexts(bip: "bap")
      expect(logger.attributes).to be_empty
    end
  end

  describe "#tag!" do
    it "adds attributes to the default context" do
      logger_with_default_context.tag!(foo: "bar")
      expect(logger_with_default_context.attributes).to eq({"foo" => "bar"})
      logger_with_default_context.tag!(baz: "qux")
      expect(logger_with_default_context.attributes).to eq({"foo" => "bar", "baz" => "qux"})
    end

    it "does nothing if there is no default context" do
      logger.tag!(foo: "bar")
      expect(logger.attributes).to be_empty
    end
  end

  describe "#untag" do
    it "removes attributes from the current context block" do
      logger.tag(foo: "bar", baz: "qux", bip: "bap") do
        logger.untag(:foo, "baz")
        expect(logger.attributes).to eq({"bip" => "bap"})
      end
    end

    it "does nothing outside of a context block" do
      logger_with_default_context.tag!(foo: "bar")
      logger_with_default_context.untag(:foo)
      expect(logger_with_default_context.attributes).to eq({"foo" => "bar"})
    end
  end

  describe "#untag!" do
    it "removes attributes from the default context" do
      logger_with_default_context.tag!(foo: "bar", baz: "qux", bip: "bap")
      logger_with_default_context.untag!(:foo, "baz")
      expect(logger_with_default_context.attributes).to eq({"bip" => "bap"})
    end

    it "does nothing if the logger does not have a default context" do
      logger.untag!(:foo)
      expect(logger.attributes).to be_empty
    end
  end

  describe "#attributes" do
    it "returns an empty hash by default" do
      expect(logger.attributes).to eq({})
      expect(logger_with_default_context.attributes).to eq({})
    end

    it "returns attributes from the default context" do
      logger_with_default_context.tag!(foo: "bar")
      expect(logger_with_default_context.attributes).to eq({"foo" => "bar"})
    end

    it "returns attributes from the current context" do
      logger.tag(foo: "bar") do
        expect(logger.attributes).to eq({"foo" => "bar"})
      end
    end

    it "merges attributes from the current context with the default context attributes" do
      logger_with_default_context.tag!(foo: "bar")
      logger_with_default_context.tag(baz: "qux") do
        expect(logger_with_default_context.attributes).to eq({"foo" => "bar", "baz" => "qux"})
      end
      expect(logger_with_default_context.attributes).to eq({"foo" => "bar"})
    end

    it "includes attributes from the global context" do
      Lumberjack.tag(foo: "bar") do
        logger.tag(baz: "qux") do
          expect(logger.attributes).to eq({"foo" => "bar", "baz" => "qux"})
        end
        expect(logger.attributes).to eq({"foo" => "bar"})
      end
    end

    it "prefers attributes from the most local context" do
      Lumberjack.tag(foo: "one") do
        expect(logger.attributes["foo"]).to eq("one")

        logger_with_default_context.tag!(foo: "two")
        expect(logger_with_default_context.attributes["foo"]).to eq("two")

        logger_with_default_context.tag(foo: "three") do
          expect(logger_with_default_context.attribute_value("foo")).to eq("three")
        end
      end
    end
  end

  describe "#attribute_value" do
    it "returns the value of a tag" do
      Lumberjack.tag(foo: "bar") do
        logger_with_default_context.tag!(baz: "qux")
        logger_with_default_context.tag(bip: "bap") do
          expect(logger_with_default_context.attribute_value("foo")).to eq("bar")
          expect(logger_with_default_context.attribute_value("baz")).to eq("qux")
          expect(logger_with_default_context.attribute_value("bip")).to eq("bap")
        end
      end
    end

    it "expands dot notation in tag names" do
      logger.tag(foo: {"bar.baz": "boo"}) do
        expect(logger.attribute_value("foo.bar.baz")).to eq("boo")
        expect(logger.attribute_value("foo.bar")).to eq("baz" => "boo")
      end
    end

    it "should expand tag name as a array to dot notation" do
      logger.tag("foo.bar" => "baz") do
        expect(logger.attribute_value([:foo, :bar])).to eq("baz")
      end
    end

    it "should return nil for a non-existent tag" do
      expect(logger.attribute_value(:non_existent)).to be_nil
    end
  end

  describe "#append_to" do
    it "does nothing if there is no context" do
      expect(logger.append_to(:tags, :foo)).to eq(logger)
      expect(logger.attributes).to be_empty
    end

    it "appends tags to the tags attribute in the current context" do
      logger.context do
        logger.append_to(:tags, :foo, :bar)
        expect(logger.attributes["tags"]).to eq([:foo, :bar])

        logger.append_to(:tags, [:baz])
        expect(logger.attributes["tags"]).to eq([:foo, :bar, :baz])

        logger.context do
          logger.append_to(:tags, :qux)
          expect(logger.attributes["tags"]).to eq([:foo, :bar, :baz, :qux])
        end

        expect(logger.attributes["tags"]).to eq([:foo, :bar, :baz])
      end
    end

    it "appends to the tags attribute inside a block" do
      logger.append_to(:tags, [:foo, :bar]) do
        expect(logger.attributes["tags"]).to eq([:foo, :bar])

        logger.append_to(:tags, [:baz]) do
          expect(logger.attributes["tags"]).to eq([:foo, :bar, :baz])
        end

        expect(logger.attributes["tags"]).to eq([:foo, :bar])
      end
    end

    it "returns the logger instance when called without a block" do
      logger.context do
        expect(logger.append_to(:tags, [:foo])).to eq(logger)
      end
    end

    it "returns the result of the block" do
      result = logger.append_to(:tags, [:foo]) { :foobar }
      expect(result).to eq(:foobar)
    end
  end

  describe "#clear_attributes" do
    it "removes all attributes from the current, default, and global contexts for the duration of the block" do
      Lumberjack.tag(foo: "bar") do
        logger_with_default_context.tag!(baz: "qux")
        logger_with_default_context.tag(bip: "bap") do
          expect(logger_with_default_context.attributes.length).to eq(3)

          logger_with_default_context.clear_attributes do
            expect(logger_with_default_context.attributes).to be_empty

            logger_with_default_context.tag(moo: "mip") do
              expect(logger_with_default_context.attributes).to eq({"moo" => "mip"})
            end
          end
        end
      end
    end

    it "returns the result of the block" do
      result = logger.clear_attributes { :foobar }
      expect(result).to eq(:foobar)
    end
  end

  describe "#fork" do
    it "returns a local logger that has an isolated context from the current logger" do
      logger = Lumberjack::Logger.new(:test)
      logger.tag!(one: 1, two: 2)
      forked_logger = logger.fork

      expect(forked_logger.level).to eq logger.level
      forked_logger.level = :warn
      expect(forked_logger.level).to_not eq logger.level

      expect(forked_logger.progname).to eq logger.progname
      forked_logger.progname = "ForkedLogger"
      expect(forked_logger.progname).to_not eq logger.progname

      expect(forked_logger.attributes).to eq({})
      forked_logger.tag!(foo: "bar", two: 22)
      expect(forked_logger.attributes).to eq({"two" => 22, "foo" => "bar"})

      logger.tag!(three: 3)
      expect(forked_logger.attributes).to eq({"two" => 22, "foo" => "bar"})
    end

    it "can set the level on the local logger" do
      forked_logger = logger.fork(level: :warn)
      expect(forked_logger.level).to eq(Logger::WARN)
    end

    it "can set the progname on the local logger" do
      forked_logger = logger.fork(progname: "ForkedLogger")
      expect(forked_logger.progname).to eq("ForkedLogger")
    end

    it "can set attributes on the local logger" do
      forked_logger = logger.fork(attributes: {foo: "bar"})
      expect(forked_logger.attributes).to eq({"foo" => "bar"})
    end
  end

  [:fatal, :error, :warn, :info, :debug, :unknown, :trace].each do |severity|
    describe "##{severity}" do
      it "returns true" do
        result = logger.public_send(severity, "Message")
        expect(result).to be true
      end

      it "logs an entry as #{severity}" do
        logger.public_send(severity, "Message")
        expect(logger.entries.first).to eq({
          severity: Lumberjack::Severity.coerce(severity),
          message: "Message",
          progname: nil,
          attributes: nil
        })
      end

      it "logs an entry as #{severity} with the message in a block" do
        logger.public_send(severity) { "Message" }
        expect(logger.entries.first).to eq({
          severity: Lumberjack::Severity.coerce(severity),
          message: "Message",
          progname: nil,
          attributes: nil
        })
      end

      it "logs an entry as #{severity} with a progname" do
        logger.public_send(severity, "Message", "myApp")
        expect(logger.entries.first).to eq({
          severity: Lumberjack::Severity.coerce(severity),
          message: "Message",
          progname: "myApp",
          attributes: nil
        })
      end

      it "logs an entry as #{severity} with attributes" do
        logger.public_send(severity, "Message", foo: "bar")
        expect(logger.entries.first).to eq({
          severity: Lumberjack::Severity.coerce(severity),
          message: "Message",
          progname: nil,
          attributes: {foo: "bar"}
        })
      end

      it "logs an entry as #{severity} with attributes and the message in a block" do
        logger.public_send(severity, foo: "bar") { "Message" }
        expect(logger.entries.first).to eq({
          severity: Lumberjack::Severity.coerce(severity),
          message: "Message",
          progname: nil,
          attributes: {foo: "bar"}
        })
      end

      it "logs an entry as #{severity} with a progname and the message in a block" do
        logger.public_send(severity, "myApp") { "Message" }
        expect(logger.entries.first).to eq({
          severity: Lumberjack::Severity.coerce(severity),
          message: "Message",
          progname: "myApp",
          attributes: nil
        })
      end

      it "does not log an entry if the level is greater than #{severity}" do
        logger.with_level(Lumberjack::Severity.coerce(severity) + 1) do
          logger.public_send(severity) { raise NotImplementedError }
          expect(logger.entries).to be_empty
        end
      end

      it "does not log nil entries even if there are context attributes" do
        logger.tag(foo: "bar") do
          logger.public_send(severity, nil)
          logger.public_send(severity, "", {})
        end
        expect(logger.entries).to be_empty
      end

      it "does log nil if there are explicit attributes" do
        logger.public_send(severity, nil, {foo: "bar"})
        expect(logger.entries).to include({
          severity: Lumberjack::Severity.coerce(severity),
          message: nil,
          progname: nil,
          attributes: {foo: "bar"}
        })
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
