# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Logger do
  describe "compatibility" do
    it "should implement the same public API as the ::Logger class" do
      logger = ::Logger.new($stdout)
      lumberjack = Lumberjack::Logger.new($stdout)
      (logger.public_methods - Object.public_methods).each do |method_name|
        logger_method = logger.method(method_name)
        lumberjack_method = lumberjack.method(method_name)
        if logger_method.arity != lumberjack_method.arity
          fail "Lumberjack::Logger.#{method_name} has arity of #{lumberjack_method.arity} instead of #{logger_method.arity}"
        end
      end
    end
  end

  describe "initialization" do
    before :all do
      create_tmp_dir
    end

    after :all do
      delete_tmp_dir
    end

    it "should wrap an IO stream in a device" do
      out = StringIO.new
      logger = Lumberjack::Logger.new(out)
      expect(logger.device.class).to eq(Lumberjack::Device::Writer)
    end

    it "should have a formatter" do
      out = StringIO.new
      logger = Lumberjack::Logger.new(out)
      expect(logger.formatter).to be
    end

    it "should have a message formatter" do
      out = StringIO.new
      logger = Lumberjack::Logger.new(out)
      expect(logger.message_formatter).to be
    end

    it "should have a tag formatter" do
      out = StringIO.new
      logger = Lumberjack::Logger.new(out)
      expect(logger.tag_formatter).to be
    end

    it "should open a file path in a device" do
      logger = Lumberjack::Logger.new(File.join(tmp_dir, "log_file_1.log"))
      expect(logger.device.class).to eq(Lumberjack::Device::LogFile)
    end

    it "should open a pathname in a device" do
      logger = Lumberjack::Logger.new(Pathname.new(File.join(tmp_dir, "log_file_1.log")))
      expect(logger.device.class).to eq(Lumberjack::Device::LogFile)
    end

    it "should use the null device if the stream is :null" do
      logger = Lumberjack::Logger.new(:null)
      expect(logger.device.class).to eq(Lumberjack::Device::Null)
    end

    it "should set the level with a numeric" do
      logger = Lumberjack::Logger.new(:null, level: Logger::WARN)
      expect(logger.level).to eq(Logger::WARN)
    end

    it "should set the level with a level" do
      logger = Lumberjack::Logger.new(:null, level: :warn)
      expect(logger.level).to eq(Logger::WARN)
    end

    it "should default the level to DEBUG" do
      logger = Lumberjack::Logger.new(:null)
      expect(logger.level).to eq(Logger::DEBUG)
    end

    it "should set the level within a block" do
      logger = Lumberjack::Logger.new(:null, level: :warn)
      retval = logger.with_level(:info) do
        expect(logger.level).to eq(Logger::INFO)
        :foo
      end
      expect(retval).to eq(:foo)
      expect(logger.level).to eq(Logger::WARN)
    end

    it "should set the progname" do
      logger = Lumberjack::Logger.new(:null, progname: "app")
      expect(logger.progname).to eq("app")
    end

    it "should create a thread to flush the device" do
      expect(Thread).to receive(:new)
      Lumberjack::Logger.new(:null, flush_seconds: 10)
    end
  end

  describe "#set_progname" do
    it "should be able to set the progname in a block" do
      logger = Lumberjack::Logger.new(StringIO.new)
      logger.set_progname("app")
      expect(logger.progname).to eq("app")
      block_executed = false
      logger.set_progname("xxx") do
        block_executed = true
        expect(logger.progname).to eq("xxx")
      end
      expect(block_executed).to eq(true)
      expect(logger.progname).to eq("app")
    end

    it "should be able to set the local progname in a block" do
      logger = Lumberjack::Logger.new(StringIO.new)
      logger.set_progname("app")
      logger.with_progname("xxx") do
        expect(logger.progname).to eq("xxx")
      end
      expect(logger.progname).to eq("app")
    end

    it "should only affect the current fiber when changing the progname in a block" do
      out = StringIO.new
      logger = Lumberjack::Logger.new(out, progname: "thread1", template: ":progname :message")
      Fiber.new do
        logger.set_progname("fiber1") do
          expect(logger.progname).to eq("fiber1")
        end
      end.resume

      expect(logger.progname).to eq("thread1")
    end
  end

  describe "#device" do
    it "should be able to open a new device by setting the device attribute" do
      logger = Lumberjack::Logger.new(:null)
      out = StringIO.new
      logger.device = out
      expect(logger.device.class).to eq(Lumberjack::Device::Writer)
      logger.info("foo")
      logger.flush
      expect(out.string).to include("foo\n")
    end
  end

  describe "#datetime_format" do
    it "should be able to set the datetime format for timestamps on the log device" do
      out = StringIO.new
      logger = Lumberjack::Logger.new(out, template: ":time :message", datetime_format: "%Y-%m-%d")
      expect(logger.datetime_format).to eq "%Y-%m-%d"
      Timecop.freeze do
        logger.info("one")
        logger.datetime_format = "%m-%d-%Y"
        expect(logger.datetime_format).to eq "%m-%d-%Y"
        logger.info("two")
        logger.flush
        expect(out.string).to eq "#{Time.now.strftime("%Y-%m-%d")} one\n#{Time.now.strftime("%m-%d-%Y")} two\n"
      end
    end
  end

  describe "flushing" do
    it "should autoflush the buffer if it hasn't been flushed in a specified number of seconds" do
      out = StringIO.new
      logger = Lumberjack::Logger.new(out, flush_seconds: 0.1, level: Logger::INFO, template: ":message", buffer_size: 32767)
      logger.info("message 1")
      logger.info("message 2")
      expect(out.string).to eq("")
      sleep(0.15)
      expect(out.string.split(Lumberjack::LINE_SEPARATOR)).to eq(["message 1", "message 2"])
      logger.info("message 3")
      expect(out.string).not_to include("message 3")
      sleep(0.15)
      expect(out.string.split(Lumberjack::LINE_SEPARATOR)).to eq(["message 1", "message 2", "message 3"])
    end

    it "should write the log entries to the device on flush and update the last flushed time" do
      out = StringIO.new
      logger = Lumberjack::Logger.new(out, level: Logger::INFO, template: ":message", buffer_size: 32767)
      logger.info("message 1")
      expect(out.string).to eq("")
      last_flushed_at = logger.last_flushed_at
      logger.flush
      expect(out.string.split(Lumberjack::LINE_SEPARATOR)).to eq(["message 1"])
      expect(logger.last_flushed_at).to be >= last_flushed_at
    end

    it "should flush the buffer and close the devices" do
      out = StringIO.new
      logger = Lumberjack::Logger.new(out, level: Logger::INFO, template: ":message", buffer_size: 32767)
      logger.info("message 1")
      expect(out.string).to eq("")
      expect(logger.closed?).to eq false
      logger.close
      expect(out.string.split(Lumberjack::LINE_SEPARATOR)).to eq(["message 1"])
      expect(out).to be_closed
      expect(logger.closed?).to eq true
    end

    it "should reopen the devices" do
      out = StringIO.new
      logger = Lumberjack::Logger.new(out, level: Logger::INFO, template: ":message", buffer_size: 32767)
      logger.close
      expect(logger.device).to receive(:reopen).and_call_original
      logger.reopen
      expect(logger.closed?).to eq false
    end
  end

  describe "logging methods" do
    let(:out) { StringIO.new }
    let(:device) { Lumberjack::Device::Writer.new(out, buffer_size: 0, template: "[:time :severity :progname(:pid)] :message :tags") }
    let(:logger) { Lumberjack::Logger.new(device, level: Logger::INFO, progname: "app") }
    let(:n) { Lumberjack::LINE_SEPARATOR }

    describe "add" do
      it "should add entries with a numeric severity and a message" do
        time = Time.parse("2011-01-30T12:31:56.123")
        allow(Time).to receive_messages(now: time)
        logger.add(Logger::INFO, "test")
        expect(out.string.chomp).to eq("[2011-01-30T12:31:56.123 INFO app(#{Process.pid})] test")
      end

      it "should add entries with a severity label" do
        time = Time.parse("2011-01-30T12:31:56.123")
        allow(Time).to receive_messages(now: time)
        logger.add(:info, "test")
        expect(out.string.chomp).to eq("[2011-01-30T12:31:56.123 INFO app(#{Process.pid})] test")
      end

      it "should add entries with a custom progname and message" do
        time = Time.parse("2011-01-30T12:31:56.123")
        allow(Time).to receive_messages(now: time)
        logger.add(Logger::INFO, "test", "spec")
        expect(out.string.chomp).to eq("[2011-01-30T12:31:56.123 INFO spec(#{Process.pid})] test")
      end

      it "should add entries with a local progname and message" do
        time = Time.parse("2011-01-30T12:31:56.123")
        allow(Time).to receive_messages(now: time)
        logger.set_progname("block") do
          logger.add(Logger::INFO, "test")
        end
        expect(out.string.chomp).to eq("[2011-01-30T12:31:56.123 INFO block(#{Process.pid})] test")
      end

      it "should add entries with a progname but no message or block" do
        time = Time.parse("2011-01-30T12:31:56.123")
        allow(Time).to receive_messages(now: time)
        logger.set_progname("default") do
          logger.add(Logger::INFO, nil, "message")
        end
        expect(out.string.chomp).to eq("[2011-01-30T12:31:56.123 INFO default(#{Process.pid})] message")
      end

      it "should add entries with a block" do
        time = Time.parse("2011-01-30T12:31:56.123")
        allow(Time).to receive_messages(now: time)
        logger.add(Logger::INFO) { "test" }
        expect(out.string.chomp).to eq("[2011-01-30T12:31:56.123 INFO app(#{Process.pid})] test")
      end

      it "should log entries (::Logger compatibility)" do
        time = Time.parse("2011-01-30T12:31:56.123")
        allow(Time).to receive_messages(now: time)
        logger.log(Logger::INFO, "test")
        expect(out.string.chomp).to eq("[2011-01-30T12:31:56.123 INFO app(#{Process.pid})] test")
      end

      it "should append messages with ANY severity to the log" do
        time = Time.parse("2011-01-30T12:31:56.123")
        allow(Time).to receive_messages(now: time)
        logger << "test"
        expect(out.string.chomp).to eq("[2011-01-30T12:31:56.123 ANY app(#{Process.pid})] test")
      end
    end

    describe "add_entry" do
      it "should add entries with tags" do
        time = Time.parse("2011-01-30T12:31:56.123")
        allow(Time).to receive_messages(now: time)
        logger.add_entry(Logger::INFO, "test", "spec", "tag" => "ABCD")
        expect(out.string.chomp).to eq("[2011-01-30T12:31:56.123 INFO spec(#{Process.pid})] test [tag:ABCD]")
      end

      it "should handle malformed tags" do
        time = Time.parse("2011-01-30T12:31:56.123")
        allow(Time).to receive_messages(now: time)
        logger.add_entry(Logger::INFO, "test", "spec", "ABCD")
        expect(out.string.chomp).to eq("[2011-01-30T12:31:56.123 INFO spec(#{Process.pid})] test")
      end

      it "should ouput entries to STDERR if they can't be written the the device" do
        stderr = $stderr
        $stderr = StringIO.new
        begin
          time = Time.parse("2011-01-30T12:31:56.123")
          allow(Time).to receive_messages(now: time)
          expect(device).to receive(:write).and_raise(StandardError.new("Cannot write to device"))
          logger.add_entry(Logger::INFO, "test")
          expect($stderr.string).to include("[2011-01-30T12:31:56.123 INFO app(#{Process.pid})] test")
          expect($stderr.string).to include("StandardError: Cannot write to device")
        ensure
          $stderr = stderr
        end
      end

      it "should call Proc tag values" do
        time = Time.parse("2011-01-30T12:31:56.123")
        allow(Time).to receive_messages(now: time)
        logger.add_entry(Logger::INFO, "test", "spec", tag: lambda { "foo" })
        expect(out.string.chomp).to eq("[2011-01-30T12:31:56.123 INFO spec(#{Process.pid})] test [tag:foo]")
      end

      it "should not get into infinite loops by logging entries while logging entries" do
        time = Time.parse("2011-01-30T12:31:56.123")
        allow(Time).to receive_messages(now: time)
        tag_proc = lambda do
          logger.warn("inner logging")
          "foo"
        end
        logger.add_entry(Logger::INFO, "test", "spec", tag: tag_proc)
        expect(out.string.chomp).to eq("[2011-01-30T12:31:56.123 INFO spec(#{Process.pid})] test [tag:foo]")
      end
    end

    %w[fatal error warn info debug].each do |level|
      describe level do
        around :each do |example|
          Timecop.freeze(time) do
            example.call
          end
        end

        before :each do
          logger.level = level
        end

        let(:time) { Time.at(1296419516) }
        let(:timestamp) { time.strftime("%Y-%m-%dT%H:%M:%S.%3N") }

        it "should log a message string" do
          logger.send(level, "test")
          expect(out.string.chomp).to eq("[#{timestamp} #{level.upcase} app(#{Process.pid})] test")
        end

        it "should log a message string with a progname" do
          logger.send(level, "test", "spec")
          expect(out.string.chomp).to eq("[#{timestamp} #{level.upcase} spec(#{Process.pid})] test")
        end

        it "should log a message string with tags" do
          logger.send(level, "test", tag: 1)
          expect(out.string.chomp).to eq("[#{timestamp} #{level.upcase} app(#{Process.pid})] test [tag:1]")
        end

        it "should log a message block" do
          logger.send(level) { "test" }
          expect(out.string.chomp).to eq("[#{timestamp} #{level.upcase} app(#{Process.pid})] test")
        end

        it "should log a message block with a progname" do
          logger.send(level, "spec") { "test" }
          expect(out.string.chomp).to eq("[#{timestamp} #{level.upcase} spec(#{Process.pid})] test")
        end

        it "should log a message block with tags" do
          logger.send(level, tag: 1) { "test" }
          expect(out.string.chomp).to eq("[#{timestamp} #{level.upcase} app(#{Process.pid})] test [tag:1]")
        end

        it "should log a message block with a progname and tags" do
          logger.send(level, "spec", tag: 1) { "test" }
          expect(out.string.chomp).to eq("[#{timestamp} #{level.upcase} spec(#{Process.pid})] test [tag:1]")
        end

        it "should log a message block with a progname and tags" do
          logger.send(level, {tag: 1}, "spec") { "test" }
          expect(out.string.chomp).to eq("[#{timestamp} #{level.upcase} spec(#{Process.pid})] test [tag:1]")
        end
      end
    end

    describe "message" do
      it "should apply the default formatter to the message" do
        logger = Lumberjack::Logger.new(out, buffer_size: 0, template: ":message")
        logger.formatter.add(String) { |msg| msg.upcase }
        logger.info("test")
        expect(out.string.chomp).to eq "TEST"
      end

      it "should apply the message formatter instead of the default formatter if it applies" do
        logger = Lumberjack::Logger.new(out, buffer_size: 0, template: ":message")
        logger.formatter.add(String) { |msg| msg.upcase }
        logger.message_formatter.add(String) { |msg| msg.reverse }
        logger.info("test")
        expect(out.string.chomp).to eq "tset"
      end

      it "should copy tags from the message if the formatter returns a Lumberjack::Formatter::TaggedMessage" do
        logger = Lumberjack::Logger.new(out, buffer_size: 0, template: ":message :tags")
        logger.formatter.add(String) { |msg| Lumberjack::Formatter::TaggedMessage.new(msg.upcase, tag: msg.downcase) }
        logger.info("Test")
        expect(out.string.chomp).to eq "TEST [tag:test]"
      end
    end

    describe "#tag_globally" do
      let(:device) { Lumberjack::Device::Writer.new(out, buffer_size: 0, template: ":message - :count - :tags") }

      it "should be able to add global tags to the logger" do
        logger.tag_globally(count: 1, foo: "bar")
        logger.info("one")
        logger.info("two", count: 2)
        lines = out.string.split(n)
        expect(lines[0]).to eq "one - 1 - [foo:bar]"
        expect(lines[1]).to eq "two - 2 - [foo:bar]"
      end
    end

    describe "#remove_tag" do
      let(:device) { Lumberjack::Device::Writer.new(out, buffer_size: 0, template: ":message - :count - :tags") }

      it "should remove context tags in a context block and global tags outside of one" do
        logger.tag!(foo: "bar", wip: "wap")
        logger.context do
          logger.tag(baz: "boo", bip: "bap")
          logger.remove_tag(:baz)
          logger.remove_tag(:foo)
          expect(logger.tags).to eq({"foo" => "bar", "wip" => "wap", "bip" => "bap"})
        end
        logger.remove_tag(:foo)
        expect(logger.tags).to eq({"wip" => "wap"})
      end

      it "should be able to extract tags from an object with a formatter that returns Lumberjack::Formatter::TaggedMessage" do
        logger.formatter.add(Exception, ->(e) {
          Lumberjack::Formatter::TaggedMessage.new(e.inspect, {message: e.message, class: e.class.name})
        })
        error = StandardError.new("foobar")
        logger.info(error)
        line = out.string.chomp
        expect(line).to eq "#{error.inspect} -  - [message:foobar] [class:StandardError]"
      end

      it "should apply a tag formatter to the tags" do
        logger.tag_formatter.add(:foo, &:reverse).add(:count) { |val| val * 100 }
        logger.info("message", count: 2, foo: "abc")
        line = out.string.chomp
        expect(line).to eq "message - 200 - [foo:cba]"
      end
    end
  end
end
